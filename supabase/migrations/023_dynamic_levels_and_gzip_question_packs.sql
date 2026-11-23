-- ==============================================================================
-- 023: Dynamic Levels, Rotating Pool, Bulk JSON Importer & Gzip CDN Question Packs
-- ==============================================================================
-- 100% Additive-Only & Backward Compatible with Live Production 1.1.0+21:
--   - Adds safe defaulted columns to `public.quiz_categories`
--   - Keeps `public.get_cms_bundle` 100% untouched for live 1.1.0+21 clients
--   - Adds `public.get_cms_bundle_v2` for 1.2.0+22 clients (omits raw PostgreSQL
--     `quiz_questions` rows for categories that have a published Gzip CDN pack)
--   - Creates `question-packs` Storage bucket (public SELECT, admin-only write)
--   - Adds atomic bulk upsert & pack export/publish RPCs with strict validation:
--       * Cross-category ID collision guard
--       * Non-empty validation for all 4 options
--       * Safe `.json.gz` storage path guard (no `..` traversal)
--   - Complies strictly with AGENTS.md Rule #2:
--     `#variable_conflict use_column` + `SET search_path = public, auth`
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Extend `public.quiz_categories` with Flexible Level & Gzip Pack Metadata
-- ------------------------------------------------------------------------------
ALTER TABLE public.quiz_categories
    ADD COLUMN IF NOT EXISTS questions_per_level INTEGER NOT NULL DEFAULT 10
        CHECK (questions_per_level BETWEEN 1 AND 100),
    ADD COLUMN IF NOT EXISTS level_draw_mode TEXT NOT NULL DEFAULT 'fixed'
        CHECK (level_draw_mode IN ('fixed', 'rotating_pool')),
    ADD COLUMN IF NOT EXISTS pack_version INTEGER NOT NULL DEFAULT 0
        CHECK (pack_version >= 0),
    ADD COLUMN IF NOT EXISTS pack_storage_path TEXT NOT NULL DEFAULT '';

-- ------------------------------------------------------------------------------
-- 2. Storage Bucket `question-packs` (Public Read, Verified Admin-Only Write)
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'question-packs',
    'question-packs',
    TRUE,
    5242880, -- 5 MB ceiling per compressed pack (~50,000 questions)
    ARRAY['application/octet-stream', 'application/json', 'application/gzip']
)
ON CONFLICT (id) DO UPDATE
SET public = TRUE,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Public read question-packs" ON storage.objects;
CREATE POLICY "Public read question-packs"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'question-packs');

DROP POLICY IF EXISTS "Verified admins insert question-packs" ON storage.objects;
CREATE POLICY "Verified admins insert question-packs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'question-packs' AND public.check_is_admin());

DROP POLICY IF EXISTS "Verified admins update question-packs" ON storage.objects;
CREATE POLICY "Verified admins update question-packs"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'question-packs' AND public.check_is_admin())
WITH CHECK (bucket_id = 'question-packs' AND public.check_is_admin());

DROP POLICY IF EXISTS "Verified admins delete question-packs" ON storage.objects;
CREATE POLICY "Verified admins delete question-packs"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'question-packs' AND public.check_is_admin());

-- ------------------------------------------------------------------------------
-- 3. `get_cms_bundle_v2`: Pack-Aware CMS Sync for 1.2.0+22 Clients
--    (Leaves `get_cms_bundle` untouched so live 1.1.0+21 clients never break.
--     Omits raw `quiz_questions` rows for categories with `pack_version > 0`.)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_cms_bundle_v2(
    p_client_cms_version BIGINT DEFAULT 0,
    p_owned_item_ids TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_cms_version BIGINT := 1;
    v_client_ver BIGINT := GREATEST(0, COALESCE(p_client_cms_version, 0));
    v_is_incremental BOOLEAN := FALSE;
    v_owned TEXT[] := COALESCE(p_owned_item_ids, ARRAY[]::TEXT[]);
    v_store_items JSONB := '[]'::jsonb;
    v_lib_sections JSONB := '[]'::jsonb;
    v_lib_items JSONB := '[]'::jsonb;
    v_quiz_cats JSONB := '[]'::jsonb;
    v_quiz_questions JSONB := '[]'::jsonb;
BEGIN
    SELECT COALESCE(cfg.cms_version, 1)
    INTO v_cms_version
    FROM public.app_release_config cfg
    WHERE cfg.platform = 'android'
    LIMIT 1;
    v_cms_version := COALESCE(v_cms_version, 1);

    IF v_client_ver > 0 AND v_client_ver >= v_cms_version THEN
        RETURN jsonb_build_object(
            'changed', FALSE,
            'cms_version', v_cms_version,
            'server_time', NOW()
        );
    END IF;

    v_is_incremental := (v_client_ver > 0);

    SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.category, s.sort_order, s.min_level, s.id), '[]'::jsonb)
    INTO v_store_items
    FROM public.store_items s
    WHERE (
        v_is_incremental
        AND s.cms_revision > v_client_ver
    ) OR (
        NOT v_is_incremental
        AND (
            s.is_visible = TRUE
            OR s.id = ANY(v_owned)
            OR (
                v_uid IS NOT NULL
                AND EXISTS (
                    SELECT 1 FROM public.user_inventory ui
                    WHERE ui.user_id = v_uid AND ui.item_id = s.id
                )
            )
        )
    );

    SELECT COALESCE(jsonb_agg(to_jsonb(ls) ORDER BY ls.sort_order, ls.id), '[]'::jsonb)
    INTO v_lib_sections
    FROM public.library_sections ls
    WHERE (v_is_incremental AND ls.cms_revision > v_client_ver)
       OR (NOT v_is_incremental AND ls.is_visible = TRUE);

    SELECT COALESCE(jsonb_agg(to_jsonb(li) ORDER BY li.section_id, li.sort_order, li.id), '[]'::jsonb)
    INTO v_lib_items
    FROM public.library_items li
    WHERE (v_is_incremental AND li.cms_revision > v_client_ver)
       OR (NOT v_is_incremental AND li.is_visible = TRUE);

    -- Includes new columns: questions_per_level, level_draw_mode, pack_version, pack_storage_path
    SELECT COALESCE(jsonb_agg(to_jsonb(qc) ORDER BY qc.sort_order, qc.id), '[]'::jsonb)
    INTO v_quiz_cats
    FROM public.quiz_categories qc
    WHERE (v_is_incremental AND qc.cms_revision > v_client_ver)
       OR (NOT v_is_incremental AND qc.is_visible = TRUE);

    -- Only return raw PostgreSQL quiz_questions for categories WITHOUT a published Gzip pack
    -- (categories with pack_version > 0 are delivered via compressed CDN Storage packs).
    SELECT COALESCE(jsonb_agg(to_jsonb(qq) ORDER BY qq.category_id, qq.level_number, qq.sort_order, qq.id), '[]'::jsonb)
    INTO v_quiz_questions
    FROM public.quiz_questions qq
    LEFT JOIN public.quiz_categories qc ON qc.id = qq.category_id
    WHERE COALESCE(qc.pack_version, 0) = 0
      AND (
          (v_is_incremental AND qq.cms_revision > v_client_ver)
          OR (NOT v_is_incremental AND qq.is_visible = TRUE)
      );

    RETURN jsonb_build_object(
        'changed', TRUE,
        'incremental', v_is_incremental,
        'cms_version', v_cms_version,
        'server_time', NOW(),
        'store_items', v_store_items,
        'library_sections', v_lib_sections,
        'library_items', v_lib_items,
        'quiz_categories', v_quiz_cats,
        'quiz_questions', v_quiz_questions
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_cms_bundle_v2(BIGINT, TEXT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_cms_bundle_v2(BIGINT, TEXT[]) TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. `admin_update_quiz_category_config`: Flexible Levels & Rotating Pool Config
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_update_quiz_category_config(
    p_category_id TEXT,
    p_total_levels INTEGER DEFAULT NULL,
    p_questions_per_level INTEGER DEFAULT NULL,
    p_level_draw_mode TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_cat TEXT := LOWER(BTRIM(COALESCE(p_category_id, '')));
    v_mode TEXT := LOWER(BTRIM(COALESCE(p_level_draw_mode, '')));
    v_new_cms BIGINT;
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_cat = '' THEN
        RAISE EXCEPTION 'Invalid category id';
    END IF;

    IF v_mode <> '' AND v_mode NOT IN ('fixed', 'rotating_pool') THEN
        RAISE EXCEPTION 'Invalid level_draw_mode: must be fixed or rotating_pool';
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    UPDATE public.quiz_categories qc
    SET total_levels = CASE
            WHEN p_total_levels IS NOT NULL THEN GREATEST(1, LEAST(100, p_total_levels))
            ELSE qc.total_levels
        END,
        questions_per_level = CASE
            WHEN p_questions_per_level IS NOT NULL THEN GREATEST(1, LEAST(100, p_questions_per_level))
            ELSE qc.questions_per_level
        END,
        level_draw_mode = CASE
            WHEN v_mode <> '' THEN v_mode
            ELSE qc.level_draw_mode
        END,
        cms_revision = v_new_cms,
        updated_at = NOW()
    WHERE qc.id = v_cat
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quiz category not found: %', v_cat;
    END IF;

    PERFORM public._write_admin_audit_log(
        'update_quiz_category_config',
        'quiz_category',
        v_cat,
        'تحديث إعدادات المستويات ونمط السحب',
        jsonb_build_object(
            'total_levels', v_row.total_levels,
            'questions_per_level', v_row.questions_per_level,
            'level_draw_mode', v_row.level_draw_mode,
            'cms_revision', v_new_cms
        )
    );

    RETURN to_jsonb(v_row) || jsonb_build_object('cms_version', v_new_cms);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_quiz_category_config(TEXT, INTEGER, INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_quiz_category_config(TEXT, INTEGER, INTEGER, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. `admin_bulk_upsert_quiz_questions`: Atomic Chunked JSON Bulk Importer (<=500/call)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_bulk_upsert_quiz_questions(
    p_category_id TEXT,
    p_questions JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_cat TEXT := LOWER(BTRIM(COALESCE(p_category_id, '')));
    v_count INTEGER;
    v_item JSONB;
    v_id TEXT;
    v_existing_cat TEXT;
    v_lvl INTEGER;
    v_qtext TEXT;
    v_opts JSONB;
    v_opt_idx INTEGER;
    v_correct INTEGER;
    v_expl TEXT;
    v_scope TEXT;
    v_sort INTEGER;
    v_vis BOOLEAN;
    v_upserted INTEGER := 0;
    v_max_level INTEGER := 1;
    v_new_cms BIGINT;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.quiz_categories qc WHERE qc.id = v_cat) THEN
        RAISE EXCEPTION 'Quiz category does not exist: %', v_cat;
    END IF;

    IF p_questions IS NULL OR jsonb_typeof(p_questions) <> 'array' THEN
        RAISE EXCEPTION 'p_questions must be a JSON array';
    END IF;

    v_count := jsonb_array_length(p_questions);
    IF v_count < 1 OR v_count > 500 THEN
        RAISE EXCEPTION 'Batch size must be between 1 and 500 questions (got %)', v_count;
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_questions)
    LOOP
        v_id := BTRIM(COALESCE(v_item->>'id', ''));
        IF v_id = '' OR v_id !~ '^[a-zA-Z0-9_-]{3,80}$' THEN
            RAISE EXCEPTION 'Invalid question id in batch: %', v_id;
        END IF;

        -- Prevent cross-category ID hijacking/collision
        SELECT qq.category_id
        INTO v_existing_cat
        FROM public.quiz_questions qq
        WHERE qq.id = v_id;

        IF v_existing_cat IS NOT NULL AND v_existing_cat <> v_cat THEN
            RAISE EXCEPTION 'Cross-category ID collision: question "%" already belongs to category "%" (cannot import into "%")', v_id, v_existing_cat, v_cat;
        END IF;

        v_lvl := GREATEST(1, LEAST(100, COALESCE((v_item->>'level_number')::INTEGER, 1)));
        v_qtext := BTRIM(COALESCE(v_item->>'question_text', ''));
        IF char_length(v_qtext) < 3 THEN
            RAISE EXCEPTION 'Question text too short for id: %', v_id;
        END IF;

        v_opts := v_item->'options';
        IF v_opts IS NULL OR jsonb_typeof(v_opts) <> 'array' OR jsonb_array_length(v_opts) <> 4 THEN
            RAISE EXCEPTION 'Question % must have exactly 4 options', v_id;
        END IF;

        FOR v_opt_idx IN 0..3 LOOP
            IF jsonb_typeof(v_opts->v_opt_idx) <> 'string'
               OR BTRIM(COALESCE(v_opts->>v_opt_idx, '')) = '' THEN
                RAISE EXCEPTION 'Question % option % must be a non-empty string', v_id, v_opt_idx;
            END IF;
        END LOOP;

        v_correct := COALESCE((v_item->>'correct_index')::INTEGER, 0);
        IF v_correct < 0 OR v_correct > 3 THEN
            RAISE EXCEPTION 'Invalid correct_index (%) for question %', v_correct, v_id;
        END IF;

        v_expl := BTRIM(COALESCE(v_item->>'explanation', ''));
        v_scope := LOWER(BTRIM(COALESCE(v_item->>'sync_scope', 'solo_only')));
        IF v_scope NOT IN ('solo_only', 'all_with_fallback') THEN
            v_scope := 'solo_only';
        END IF;
        v_sort := COALESCE((v_item->>'sort_order')::INTEGER, 100);
        v_vis := COALESCE((v_item->>'is_visible')::BOOLEAN, TRUE);

        INSERT INTO public.quiz_questions (
            id, category_id, level_number, question_text, options,
            correct_index, explanation, sync_scope, sort_order, is_visible,
            cms_revision, updated_at
        )
        VALUES (
            v_id, v_cat, v_lvl, v_qtext, v_opts,
            v_correct, v_expl, v_scope, v_sort, v_vis,
            v_new_cms, NOW()
        )
        ON CONFLICT (id) DO UPDATE
        SET level_number = EXCLUDED.level_number,
            question_text = EXCLUDED.question_text,
            options = EXCLUDED.options,
            correct_index = EXCLUDED.correct_index,
            explanation = EXCLUDED.explanation,
            sync_scope = EXCLUDED.sync_scope,
            sort_order = EXCLUDED.sort_order,
            is_visible = EXCLUDED.is_visible,
            cms_revision = v_new_cms,
            updated_at = NOW();

        v_upserted := v_upserted + 1;
        IF v_lvl > v_max_level THEN
            v_max_level := v_lvl;
        END IF;
    END LOOP;

    -- Auto-expand category total_levels if imported questions exceed current cap
    UPDATE public.quiz_categories qc
    SET total_levels = GREATEST(qc.total_levels, v_max_level),
        cms_revision = v_new_cms,
        updated_at = NOW()
    WHERE qc.id = v_cat;

    PERFORM public._write_admin_audit_log(
        'bulk_upsert_quiz_questions',
        'quiz_category',
        v_cat,
        'استيراد جماعي لملف أسئلة JSON',
        jsonb_build_object(
            'upserted_count', v_upserted,
            'max_level', v_max_level,
            'cms_revision', v_new_cms
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'category_id', v_cat,
        'upserted_count', v_upserted,
        'max_level', v_max_level,
        'cms_version', v_new_cms
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_bulk_upsert_quiz_questions(TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_upsert_quiz_questions(TEXT, JSONB) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 6. `admin_export_category_pack_payload`: Exports All Visible Questions for Gzip
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_export_category_pack_payload(
    p_category_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_cat TEXT := LOWER(BTRIM(COALESCE(p_category_id, '')));
    v_cat_row RECORD;
    v_levels JSONB := '{}'::jsonb;
    v_total INTEGER := 0;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT qc.* INTO v_cat_row
    FROM public.quiz_categories qc
    WHERE qc.id = v_cat;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quiz category not found: %', v_cat;
    END IF;

    SELECT COUNT(*)
    INTO v_total
    FROM public.quiz_questions qq
    WHERE qq.category_id = v_cat
      AND qq.is_visible = TRUE;

    SELECT COALESCE(
        jsonb_object_agg(lvl_group.lvl_key, lvl_group.items),
        '{}'::jsonb
    )
    INTO v_levels
    FROM (
        SELECT
            qq.level_number::TEXT AS lvl_key,
            jsonb_agg(
                jsonb_build_object(
                    'id', qq.id,
                    'question', qq.question_text,
                    'options', qq.options,
                    'correct', qq.correct_index,
                    'explanation', qq.explanation,
                    'sortOrder', qq.sort_order,
                    'syncScope', qq.sync_scope
                )
                ORDER BY qq.sort_order, qq.id
            ) AS items
        FROM public.quiz_questions qq
        WHERE qq.category_id = v_cat
          AND qq.is_visible = TRUE
        GROUP BY qq.level_number
    ) lvl_group;

    RETURN jsonb_build_object(
        'categoryId', v_cat_row.id,
        'categoryName', v_cat_row.name,
        'description', v_cat_row.description,
        'totalLevels', v_cat_row.total_levels,
        'questionsPerLevel', v_cat_row.questions_per_level,
        'levelDrawMode', v_cat_row.level_draw_mode,
        'packVersion', v_cat_row.pack_version + 1,
        'questionsCount', v_total,
        'levels', v_levels
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_export_category_pack_payload(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_export_category_pack_payload(TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 7. `admin_publish_category_pack`: Records New Gzip Pack Path & Bumps Versions
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_publish_category_pack(
    p_category_id TEXT,
    p_pack_storage_path TEXT,
    p_questions_count INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_cat TEXT := LOWER(BTRIM(COALESCE(p_category_id, '')));
    v_path TEXT := BTRIM(COALESCE(p_pack_storage_path, ''));
    v_new_cms BIGINT;
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_cat = '' OR v_path = '' THEN
        RAISE EXCEPTION 'category_id and pack_storage_path are required';
    END IF;

    IF v_path NOT LIKE '%.json.gz'
       OR POSITION('..' IN v_path) > 0
       OR LEFT(v_path, 1) = '/' THEN
        RAISE EXCEPTION 'Invalid pack_storage_path: must end with .json.gz and must not contain ".." or leading slash';
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    UPDATE public.quiz_categories qc
    SET pack_version = qc.pack_version + 1,
        pack_storage_path = v_path,
        cms_revision = v_new_cms,
        updated_at = NOW()
    WHERE qc.id = v_cat
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quiz category not found: %', v_cat;
    END IF;

    PERFORM public._write_admin_audit_log(
        'publish_category_gzip_pack',
        'quiz_category',
        v_cat,
        'نشر حزمة أسئلة Gzip CDN للاعبين',
        jsonb_build_object(
            'pack_version', v_row.pack_version,
            'pack_storage_path', v_path,
            'questions_count', COALESCE(p_questions_count, 0),
            'cms_revision', v_new_cms
        )
    );

    RETURN to_jsonb(v_row) || jsonb_build_object('cms_version', v_new_cms);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_publish_category_pack(TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_publish_category_pack(TEXT, TEXT, INTEGER) TO authenticated, service_role;
