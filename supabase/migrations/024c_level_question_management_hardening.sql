-- ==============================================================================
-- 024c: Forensic Hardening for Migration 024 (Trigger Dedup, Full-Sync Hidden
--       Categories, Non-Gzip Delete Sync, Visibility Sync, Escaped ILIKE,
--       Half-Range & Blank-ID Guards)
-- ==============================================================================
-- Additive-Only over 024a & 024b (which are already applied live).
-- Zero signature changes -> 0 PGRST203 overloads.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Deduplicate `trg_fn_quiz_questions_touch_updated_at()` per transaction
--    (`NOW()` is transaction-stable in PostgreSQL, so `IS DISTINCT FROM NOW()`
--    prevents 200 redundant UPDATEs & `cms_version` bumps during bulk ops!)
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
        WHERE qc.id = OLD.category_id
          AND qc.questions_updated_at IS DISTINCT FROM NOW();
        RETURN OLD;
    END IF;

    UPDATE public.quiz_categories qc
    SET questions_updated_at = NOW()
    WHERE qc.id = NEW.category_id
      AND qc.questions_updated_at IS DISTINCT FROM NOW();

    IF TG_OP = 'UPDATE' AND OLD.category_id IS DISTINCT FROM NEW.category_id THEN
        UPDATE public.quiz_categories qc
        SET questions_updated_at = NOW()
        WHERE qc.id = OLD.category_id
          AND qc.questions_updated_at IS DISTINCT FROM NOW();
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_fn_quiz_questions_touch_updated_at() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.trg_fn_quiz_questions_touch_updated_at() TO service_role;

-- ------------------------------------------------------------------------------
-- 2. Harden `get_cms_bundle_v2()`:
--    (a) Full sync returns ALL `quiz_categories` (including hidden rows with
--        `is_visible = false` & `availability_status = 'hidden'`) so fresh
--        installs / schema v3 upgrades hide any hidden built-in category!
--    (b) Incremental sync for changed non-Gzip categories (`pack_version = 0`
--        AND `qc.cms_revision > v_client_ver`) returns all current visible
--        questions of that category so deleted questions never linger as ghosts.
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

    -- Return ALL categories on full sync (including hidden ones with explicit
    -- is_visible=false & availability_status='hidden') so built-in defaults
    -- hidden by admin stay hidden on fresh installs & schema upgrades.
    SELECT COALESCE(
        jsonb_agg(
            (
                to_jsonb(qc)
                || jsonb_build_object(
                    'is_visible', (qc.is_visible AND qc.availability_status <> 'hidden'),
                    'availability_status', CASE
                        WHEN NOT qc.is_visible THEN 'hidden'
                        ELSE qc.availability_status
                    END,
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
    WHERE (NOT v_is_incremental)
       OR (v_is_incremental AND qc.cms_revision > v_client_ver);

    -- For non-Gzip categories (`pack_version = 0`):
    --  * Full sync: return all visible questions.
    --  * Incremental sync: return delta questions PLUS all currently visible
    --    questions of any changed non-Gzip category (`qc.cms_revision > v_client_ver`)
    --    so hard-deleted questions are cleanly purged on client mergeBundle().
    SELECT COALESCE(jsonb_agg(to_jsonb(qq) ORDER BY qq.category_id, qq.level_number, qq.sort_order, qq.id), '[]'::jsonb)
    INTO v_quiz_questions
    FROM public.quiz_questions qq
    LEFT JOIN public.quiz_categories qc ON qc.id = qq.category_id
    WHERE COALESCE(qc.pack_version, 0) = 0
      AND (
          (NOT v_is_incremental AND qq.is_visible = TRUE)
          OR (
              v_is_incremental
              AND (
                  qq.cms_revision > v_client_ver
                  OR (qq.is_visible = TRUE AND qc.cms_revision > v_client_ver)
              )
          )
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
-- 3. Reconcile `admin_set_content_visibility()` for `quiz_category`
--    so toggling visibility keeps `availability_status` & `is_locked` in sync.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_content_visibility(
    p_entity_type TEXT,
    p_id TEXT,
    p_is_visible BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_type TEXT := LOWER(BTRIM(COALESCE(p_entity_type, '')));
    v_id TEXT := BTRIM(COALESCE(p_id, ''));
    v_visible BOOLEAN := COALESCE(p_is_visible, TRUE);
    v_new_cms BIGINT;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_id = '' THEN
        RAISE EXCEPTION 'Target ID cannot be empty';
    END IF;

    IF v_type NOT IN ('store_item', 'library_section', 'library_item', 'quiz_category', 'quiz_question') THEN
        RAISE EXCEPTION 'Unsupported entity type: %', v_type;
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    IF v_type = 'store_item' THEN
        UPDATE public.store_items s
        SET is_visible = v_visible, cms_revision = v_new_cms, updated_at = NOW()
        WHERE s.id = v_id;
    ELSIF v_type = 'library_section' THEN
        UPDATE public.library_sections ls
        SET is_visible = v_visible, cms_revision = v_new_cms, updated_at = NOW()
        WHERE ls.id = v_id;
    ELSIF v_type = 'library_item' THEN
        UPDATE public.library_items li
        SET is_visible = v_visible, cms_revision = v_new_cms, updated_at = NOW()
        WHERE li.id = v_id;
    ELSIF v_type = 'quiz_category' THEN
        UPDATE public.quiz_categories qc
        SET is_visible = v_visible,
            availability_status = CASE WHEN v_visible THEN 'open' ELSE 'hidden' END,
            is_locked = CASE WHEN v_visible THEN FALSE ELSE qc.is_locked END,
            cms_revision = v_new_cms,
            updated_at = NOW()
        WHERE qc.id = v_id;
    ELSIF v_type = 'quiz_question' THEN
        UPDATE public.quiz_questions qq
        SET is_visible = v_visible, cms_revision = v_new_cms, updated_at = NOW()
        WHERE qq.id = v_id;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Record (%) not found in %', v_id, v_type;
    END IF;

    PERFORM public._write_admin_audit_log(
        CASE WHEN v_visible THEN 'cms_show_entity' ELSE 'cms_hide_entity' END,
        v_type,
        v_id,
        CASE WHEN v_visible THEN 'إظهار عنصر في المنصة' ELSE 'إخفاء عنصر من المنصة' END,
        jsonb_build_object('is_visible', v_visible, 'cms_revision', v_new_cms)
    );

    RETURN jsonb_build_object(
        'entity_type', v_type,
        'id', v_id,
        'is_visible', v_visible,
        'cms_version', v_new_cms
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_content_visibility(TEXT, TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_content_visibility(TEXT, TEXT, BOOLEAN) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. Harden `admin_browse_quiz_questions()` with escaped `ILIKE` (`\`, `%`, `_`)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_browse_quiz_questions(
    p_category_id TEXT DEFAULT NULL,
    p_level_number INTEGER DEFAULT NULL,
    p_visibility TEXT DEFAULT 'all',
    p_search TEXT DEFAULT '',
    p_page INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 25
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
    v_vis TEXT := LOWER(BTRIM(COALESCE(p_visibility, 'all')));
    v_search TEXT := BTRIM(COALESCE(p_search, ''));
    v_search_esc TEXT := '';
    v_page INTEGER := GREATEST(1, COALESCE(p_page, 1));
    v_size INTEGER := GREATEST(1, LEAST(50, COALESCE(p_page_size, 25)));
    v_offset INTEGER := (v_page - 1) * v_size;
    v_total INTEGER := 0;
    v_rows JSONB := '[]'::jsonb;
    v_pack_dirty BOOLEAN := FALSE;
    v_hidden_local TEXT[] := ARRAY[]::TEXT[];
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_vis NOT IN ('all', 'visible', 'hidden') THEN
        v_vis := 'all';
    END IF;

    IF v_search <> '' THEN
        v_search_esc := replace(replace(replace(v_search, '\', '\\'), '%', '\%'), '_', '\_');
    END IF;

    IF v_cat <> '' THEN
        SELECT
            (
                COALESCE(qc.pack_version, 0) > 0
                AND qc.questions_updated_at IS NOT NULL
                AND qc.questions_updated_at > COALESCE(qc.pack_published_at, 'epoch'::timestamptz)
            ),
            COALESCE(qc.hidden_local_question_ids, ARRAY[]::TEXT[])
        INTO v_pack_dirty, v_hidden_local
        FROM public.quiz_categories qc
        WHERE qc.id = v_cat;
    END IF;

    SELECT COUNT(*)
    INTO v_total
    FROM public.quiz_questions qq
    WHERE (v_cat = '' OR qq.category_id = v_cat)
      AND (p_level_number IS NULL OR qq.level_number = p_level_number)
      AND (
          v_vis = 'all'
          OR (v_vis = 'visible' AND qq.is_visible = TRUE)
          OR (v_vis = 'hidden' AND qq.is_visible = FALSE)
      )
      AND (
          v_search_esc = ''
          OR qq.question_text ILIKE '%' || v_search_esc || '%' ESCAPE '\'
          OR qq.id ILIKE '%' || v_search_esc || '%' ESCAPE '\'
          OR qq.explanation ILIKE '%' || v_search_esc || '%' ESCAPE '\'
      );

    SELECT COALESCE(jsonb_agg(to_jsonb(sub)), '[]'::jsonb)
    INTO v_rows
    FROM (
        SELECT qq.*
        FROM public.quiz_questions qq
        WHERE (v_cat = '' OR qq.category_id = v_cat)
          AND (p_level_number IS NULL OR qq.level_number = p_level_number)
          AND (
              v_vis = 'all'
              OR (v_vis = 'visible' AND qq.is_visible = TRUE)
              OR (v_vis = 'hidden' AND qq.is_visible = FALSE)
          )
          AND (
              v_search_esc = ''
              OR qq.question_text ILIKE '%' || v_search_esc || '%' ESCAPE '\'
              OR qq.id ILIKE '%' || v_search_esc || '%' ESCAPE '\'
              OR qq.explanation ILIKE '%' || v_search_esc || '%' ESCAPE '\'
          )
        ORDER BY qq.category_id, qq.level_number, qq.sort_order, qq.id
        LIMIT v_size
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'total_count', v_total,
        'page', v_page,
        'page_size', v_size,
        'pack_needs_republish', COALESCE(v_pack_dirty, FALSE),
        'hidden_local_question_ids', COALESCE(to_jsonb(v_hidden_local), '[]'::jsonb),
        'questions', v_rows
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_browse_quiz_questions(TEXT, INTEGER, TEXT, TEXT, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_browse_quiz_questions(TEXT, INTEGER, TEXT, TEXT, INTEGER, INTEGER) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. Harden `admin_bulk_manage_questions()`:
--    Reject half-ranges `(p_from_level IS NULL) <> (p_to_level IS NULL)` and
--    strip blank/empty strings from `p_question_ids` before evaluating `v_has_ids`.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_bulk_manage_questions(
    p_category_id TEXT,
    p_action TEXT,
    p_question_ids TEXT[] DEFAULT NULL,
    p_from_level INTEGER DEFAULT NULL,
    p_to_level INTEGER DEFAULT NULL,
    p_target_level INTEGER DEFAULT NULL
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
    v_action TEXT := LOWER(BTRIM(COALESCE(p_action, '')));
    v_clean_ids TEXT[] := ARRAY[]::TEXT[];
    v_has_ids BOOLEAN := FALSE;
    v_has_range BOOLEAN := FALSE;
    v_affected INTEGER := 0;
    v_new_cms BIGINT;
    v_pack_dirty BOOLEAN := FALSE;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_cat = '' OR NOT EXISTS (SELECT 1 FROM public.quiz_categories qc WHERE qc.id = v_cat) THEN
        RAISE EXCEPTION 'Quiz category not found: %', v_cat;
    END IF;

    IF v_action NOT IN ('show', 'hide', 'delete', 'move_level') THEN
        RAISE EXCEPTION 'Invalid bulk action: % (expected show|hide|delete|move_level)', v_action;
    END IF;

    -- Reject half-specified level range
    IF (p_from_level IS NULL) <> (p_to_level IS NULL) THEN
        RAISE EXCEPTION 'Invalid level range: both p_from_level and p_to_level must be provided together';
    END IF;

    -- Filter blank/empty IDs before evaluating safety guard
    IF p_question_ids IS NOT NULL THEN
        SELECT COALESCE(ARRAY_AGG(DISTINCT trimmed_id), ARRAY[]::TEXT[])
        INTO v_clean_ids
        FROM (
            SELECT BTRIM(COALESCE(raw_id, '')) AS trimmed_id
            FROM UNNEST(p_question_ids) AS raw_id
        ) cleaned
        WHERE trimmed_id <> '';
    END IF;

    v_has_ids := (COALESCE(array_length(v_clean_ids, 1), 0) > 0);
    v_has_range := (p_from_level IS NOT NULL AND p_to_level IS NOT NULL);

    -- Safety Guard: reject unscoped calls to prevent accidental full-category wipe
    IF NOT v_has_ids AND NOT v_has_range THEN
        RAISE EXCEPTION 'Safety guard: must specify either non-empty p_question_ids or a valid p_from_level..p_to_level range';
    END IF;

    IF v_has_range AND (p_from_level < 1 OR p_to_level > 100 OR p_from_level > p_to_level) THEN
        RAISE EXCEPTION 'Invalid level range: %..% (must satisfy 1 <= from <= to <= 100)', p_from_level, p_to_level;
    END IF;

    IF v_action = 'move_level' AND (p_target_level IS NULL OR p_target_level < 1 OR p_target_level > 100) THEN
        RAISE EXCEPTION 'Invalid target level for move_level: must be between 1 and 100';
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    IF v_action = 'delete' THEN
        DELETE FROM public.quiz_questions qq
        WHERE qq.category_id = v_cat
          AND (NOT v_has_ids OR qq.id = ANY(v_clean_ids))
          AND (NOT v_has_range OR qq.level_number BETWEEN p_from_level AND p_to_level);
        GET DIAGNOSTICS v_affected = ROW_COUNT;
    ELSIF v_action IN ('show', 'hide') THEN
        UPDATE public.quiz_questions qq
        SET is_visible = (v_action = 'show'),
            cms_revision = v_new_cms,
            updated_at = NOW()
        WHERE qq.category_id = v_cat
          AND (NOT v_has_ids OR qq.id = ANY(v_clean_ids))
          AND (NOT v_has_range OR qq.level_number BETWEEN p_from_level AND p_to_level);
        GET DIAGNOSTICS v_affected = ROW_COUNT;
    ELSIF v_action = 'move_level' THEN
        UPDATE public.quiz_questions qq
        SET level_number = p_target_level,
            cms_revision = v_new_cms,
            updated_at = NOW()
        WHERE qq.category_id = v_cat
          AND (NOT v_has_ids OR qq.id = ANY(v_clean_ids))
          AND (NOT v_has_range OR qq.level_number BETWEEN p_from_level AND p_to_level);
        GET DIAGNOSTICS v_affected = ROW_COUNT;
    END IF;

    UPDATE public.quiz_categories qc
    SET total_levels = CASE
            WHEN v_action = 'move_level' AND v_affected > 0
                THEN GREATEST(qc.total_levels, p_target_level)
            ELSE qc.total_levels
        END,
        cms_revision = v_new_cms,
        updated_at = NOW()
    WHERE qc.id = v_cat
    RETURNING (
        COALESCE(qc.pack_version, 0) > 0
        AND qc.questions_updated_at IS NOT NULL
        AND qc.questions_updated_at > COALESCE(qc.pack_published_at, 'epoch'::timestamptz)
    ) INTO v_pack_dirty;

    PERFORM public._write_admin_audit_log(
        'bulk_manage_quiz_questions',
        'quiz_category',
        v_cat,
        'إجراء جماعي على أسئلة القسم: ' || v_action,
        jsonb_build_object(
            'action', v_action,
            'affected_count', v_affected,
            'from_level', p_from_level,
            'to_level', p_to_level,
            'target_level', p_target_level,
            'ids_count', COALESCE(array_length(v_clean_ids, 1), 0),
            'cms_revision', v_new_cms
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'category_id', v_cat,
        'action', v_action,
        'affected_count', v_affected,
        'pack_needs_republish', COALESCE(v_pack_dirty, FALSE),
        'cms_version', v_new_cms
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_bulk_manage_questions(TEXT, TEXT, TEXT[], INTEGER, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_bulk_manage_questions(TEXT, TEXT, TEXT[], INTEGER, INTEGER, INTEGER) TO authenticated, service_role;
