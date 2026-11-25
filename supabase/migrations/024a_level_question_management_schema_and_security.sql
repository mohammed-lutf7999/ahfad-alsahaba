-- ==============================================================================
-- 024a: Level/Question Management Schema, Auto-Dirty Trigger & ACL Security Hardening
-- ==============================================================================
-- 100% Additive-Only & Backward Compatible with Live 1.1.0+21 / 1.2.0+22 / 1.2.1+23:
--   - Extends `public.quiz_categories` with availability_status, coming_soon_message,
--     level_overrides (JSONB), hidden_local_question_ids (TEXT[]),
--     questions_updated_at, and pack_published_at.
--   - Adds trigger `trg_quiz_questions_touch_category_ts` so ANY change in
--     `quiz_questions` (from 016/023/024b) automatically marks Gzip pack dirty.
--   - Keeps `public.get_cms_bundle` 100% untouched for live 1.1.0+21 clients.
--   - Upgrades `get_cms_bundle_v2` with backward-safe `is_locked` fallback for
--     1.2.0+22 / 1.2.1+23 clients + `hidden_question_ids` + `pack_needs_republish`.
--   - Hardens ACLs dynamically: revokes EXECUTE from PUBLIC, anon on all live
--     `admin_*` and internal `_*` functions (`--verify-live` -> 0 anon admin RPCs)
--     and drops the 2 wide-open legacy INSERT(true) policies on matches/participants.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Extend `public.quiz_categories`
-- ------------------------------------------------------------------------------
ALTER TABLE public.quiz_categories
    ADD COLUMN IF NOT EXISTS availability_status TEXT NOT NULL DEFAULT 'open',
    ADD COLUMN IF NOT EXISTS coming_soon_message TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS level_overrides JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS hidden_local_question_ids TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN IF NOT EXISTS questions_updated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS pack_published_at TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_quiz_categories_availability_status'
    ) THEN
        ALTER TABLE public.quiz_categories
            ADD CONSTRAINT chk_quiz_categories_availability_status
            CHECK (availability_status IN ('open', 'coming_soon', 'hidden'));
    END IF;
END
$$;

-- Backfill availability_status cleanly for any pre-existing hidden/locked categories
UPDATE public.quiz_categories
SET availability_status = CASE
        WHEN is_visible = FALSE THEN 'hidden'
        WHEN is_locked = TRUE THEN 'coming_soon'
        ELSE 'open'
    END
WHERE availability_status = 'open'
  AND (is_visible = FALSE OR is_locked = TRUE);

-- Backfill pack_published_at for already-published packs so they don't show false dirty state
UPDATE public.quiz_categories
SET pack_published_at = COALESCE(pack_published_at, updated_at, NOW())
WHERE pack_version > 0
  AND pack_published_at IS NULL;

-- ------------------------------------------------------------------------------
-- 2. Trigger: Automatically Touch `quiz_categories.questions_updated_at`
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_fn_quiz_questions_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE public.quiz_categories qc
        SET questions_updated_at = NOW()
        WHERE qc.id = OLD.category_id;
        RETURN OLD;
    END IF;

    UPDATE public.quiz_categories qc
    SET questions_updated_at = NOW()
    WHERE qc.id = NEW.category_id;

    IF TG_OP = 'UPDATE' AND OLD.category_id IS DISTINCT FROM NEW.category_id THEN
        UPDATE public.quiz_categories qc
        SET questions_updated_at = NOW()
        WHERE qc.id = OLD.category_id;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_fn_quiz_questions_touch_updated_at() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_fn_quiz_questions_touch_updated_at() TO service_role;

DROP TRIGGER IF EXISTS trg_quiz_questions_touch_category_ts ON public.quiz_questions;
CREATE TRIGGER trg_quiz_questions_touch_category_ts
AFTER INSERT OR UPDATE OR DELETE ON public.quiz_questions
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_quiz_questions_touch_updated_at();

-- ------------------------------------------------------------------------------
-- 3. Upgrade `get_cms_bundle_v2`: Level Overrides, Coming Soon & Hidden IDs
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

    -- Enriched category payload:
    --  * Backward-safe: `is_locked = TRUE` when availability_status = 'coming_soon'
    --    and `is_visible = FALSE` when availability_status = 'hidden' for 1.2.x clients.
    --  * Zero-lag Delta: includes `level_overrides` and `hidden_question_ids`
    --    (union of hidden_local_question_ids + hidden quiz_questions rows).
    SELECT COALESCE(
        jsonb_agg(
            (
                to_jsonb(qc)
                || jsonb_build_object(
                    'is_visible', (qc.is_visible AND qc.availability_status <> 'hidden'),
                    'is_locked', (qc.is_locked OR qc.availability_status = 'coming_soon'),
                    'pack_needs_republish', (
                        COALESCE(qc.pack_version, 0) > 0
                        AND qc.questions_updated_at IS NOT NULL
                        AND qc.questions_updated_at > COALESCE(qc.pack_published_at, 'epoch'::timestamptz)
                    ),
                    'hidden_question_ids', COALESCE(
                        (
                            SELECT to_jsonb(ARRAY(
                                SELECT DISTINCT hid
                                FROM (
                                    SELECT UNNEST(COALESCE(qc.hidden_local_question_ids, ARRAY[]::TEXT[])) AS hid
                                    UNION
                                    SELECT qq.id AS hid
                                    FROM public.quiz_questions qq
                                    WHERE qq.category_id = qc.id
                                      AND qq.is_visible = FALSE
                                ) merged_hidden
                                WHERE BTRIM(COALESCE(hid, '')) <> ''
                                ORDER BY hid
                            ))
                        ),
                        '[]'::jsonb
                    )
                )
            )
            ORDER BY qc.sort_order, qc.id
        ),
        '[]'::jsonb
    )
    INTO v_quiz_cats
    FROM public.quiz_categories qc
    WHERE (v_is_incremental AND qc.cms_revision > v_client_ver)
       OR (NOT v_is_incremental AND qc.is_visible = TRUE AND qc.availability_status <> 'hidden');

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
-- 4. Upgrade Pack Export & Publish RPCs (`hiddenIds` + `pack_published_at`)
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
    v_hidden_ids JSONB := '[]'::jsonb;
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

    SELECT COALESCE(
        to_jsonb(ARRAY(
            SELECT DISTINCT hid
            FROM (
                SELECT UNNEST(COALESCE(v_cat_row.hidden_local_question_ids, ARRAY[]::TEXT[])) AS hid
                UNION
                SELECT qq.id AS hid
                FROM public.quiz_questions qq
                WHERE qq.category_id = v_cat
                  AND qq.is_visible = FALSE
            ) h
            WHERE BTRIM(COALESCE(hid, '')) <> ''
            ORDER BY hid
        )),
        '[]'::jsonb
    )
    INTO v_hidden_ids;

    RETURN jsonb_build_object(
        'categoryId', v_cat_row.id,
        'categoryName', v_cat_row.name,
        'description', v_cat_row.description,
        'totalLevels', v_cat_row.total_levels,
        'questionsPerLevel', v_cat_row.questions_per_level,
        'levelDrawMode', v_cat_row.level_draw_mode,
        'packVersion', v_cat_row.pack_version + 1,
        'questionsCount', v_total,
        'hiddenIds', v_hidden_ids,
        'levels', v_levels
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_export_category_pack_payload(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_export_category_pack_payload(TEXT) TO authenticated, service_role;

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
        pack_published_at = NOW(),
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

    RETURN to_jsonb(v_row) || jsonb_build_object(
        'cms_version', v_new_cms,
        'pack_needs_republish', FALSE
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_publish_category_pack(TEXT, TEXT, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_publish_category_pack(TEXT, TEXT, INTEGER) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. Security Hardening (Live Audit Closures — Defense-in-Depth)
-- ------------------------------------------------------------------------------
-- A) Drop the 2 wide-open legacy INSERT(true) policies on matches/participants
--    (all match & participant creation runs inside SECURITY DEFINER RPCs).
DROP POLICY IF EXISTS "System creates matches" ON public.matches;
DROP POLICY IF EXISTS "Users can insert participant records" ON public.match_participants;

-- B) Align cancel_private_room permissions with create_private_room / join_private_room
--    (guest players can cancel waiting rooms cleanly; search_path already pinned in 021).
REVOKE ALL ON FUNCTION public.cancel_private_room(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_private_room(UUID, UUID) TO anon, authenticated, service_role;

-- C) Dynamically revoke EXECUTE from PUBLIC, anon on EVERY live admin_* and internal _* function
DO $$
DECLARE
    v_fn RECORD;
BEGIN
    FOR v_fn IN
        SELECT p.oid::regprocedure AS sig, p.proname
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
          AND (p.proname LIKE 'admin\_%' ESCAPE '\' OR p.proname LIKE '\_%' ESCAPE '\')
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', v_fn.sig);
        IF v_fn.proname LIKE 'admin\_%' ESCAPE '\'
           OR v_fn.proname IN ('_check_is_owner', '_current_actor_email') THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', v_fn.sig);
        ELSE
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM authenticated', v_fn.sig);
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', v_fn.sig);
        END IF;
    END LOOP;
END;
$$;
