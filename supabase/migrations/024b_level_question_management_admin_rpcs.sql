-- ==============================================================================
-- 024b: Admin RPCs for Level/Question Browser, Bulk Actions & Coming Soon States
-- ==============================================================================
-- All RPCs comply strictly with AGENTS.md Rule #2 & FUNCTIONS_INDEX.md charter:
--   - SECURITY DEFINER + SET search_path = public, auth + #variable_conflict use_column
--   - Verified admin check (`public.check_is_admin()`) + `admin_audit_logs` entry
--   - REVOKE ALL ... FROM PUBLIC, anon; GRANT EXECUTE ... TO authenticated, service_role
--   - Strict bulk-action safety guard (rejects unscoped bulk delete/modify)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. `admin_browse_quiz_questions`: Paginated Search & Filter Question Browser
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
          v_search = ''
          OR qq.question_text ILIKE '%' || v_search || '%'
          OR qq.id ILIKE '%' || v_search || '%'
          OR qq.explanation ILIKE '%' || v_search || '%'
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
              v_search = ''
              OR qq.question_text ILIKE '%' || v_search || '%'
              OR qq.id ILIKE '%' || v_search || '%'
              OR qq.explanation ILIKE '%' || v_search || '%'
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
-- 2. `admin_delete_quiz_question`: Delete Single Cloud Question Safely
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_delete_quiz_question(
    p_question_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_qid TEXT := BTRIM(COALESCE(p_question_id, ''));
    v_cat TEXT;
    v_lvl INTEGER;
    v_new_cms BIGINT;
    v_pack_dirty BOOLEAN := FALSE;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_qid = '' THEN
        RAISE EXCEPTION 'Question id is required';
    END IF;

    DELETE FROM public.quiz_questions qq
    WHERE qq.id = v_qid
    RETURNING qq.category_id, qq.level_number INTO v_cat, v_lvl;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Question not found: %', v_qid;
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    UPDATE public.quiz_categories qc
    SET cms_revision = v_new_cms,
        updated_at = NOW()
    WHERE qc.id = v_cat
    RETURNING (
        COALESCE(qc.pack_version, 0) > 0
        AND qc.questions_updated_at IS NOT NULL
        AND qc.questions_updated_at > COALESCE(qc.pack_published_at, 'epoch'::timestamptz)
    ) INTO v_pack_dirty;

    PERFORM public._write_admin_audit_log(
        'delete_quiz_question',
        'quiz_question',
        v_qid,
        'حذف سؤال من بنك الأسئلة السحابي',
        jsonb_build_object(
            'category_id', v_cat,
            'level_number', v_lvl,
            'cms_revision', v_new_cms
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'deleted_id', v_qid,
        'category_id', v_cat,
        'pack_needs_republish', COALESCE(v_pack_dirty, FALSE),
        'cms_version', v_new_cms
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_delete_quiz_question(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_quiz_question(TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. `admin_bulk_manage_questions`: Scoped Bulk Show / Hide / Delete / Move Level
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
    v_has_ids BOOLEAN := (p_question_ids IS NOT NULL AND COALESCE(array_length(p_question_ids, 1), 0) > 0);
    v_has_range BOOLEAN := (p_from_level IS NOT NULL AND p_to_level IS NOT NULL);
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
          AND (NOT v_has_ids OR qq.id = ANY(p_question_ids))
          AND (NOT v_has_range OR qq.level_number BETWEEN p_from_level AND p_to_level);
        GET DIAGNOSTICS v_affected = ROW_COUNT;
    ELSIF v_action IN ('show', 'hide') THEN
        UPDATE public.quiz_questions qq
        SET is_visible = (v_action = 'show'),
            cms_revision = v_new_cms,
            updated_at = NOW()
        WHERE qq.category_id = v_cat
          AND (NOT v_has_ids OR qq.id = ANY(p_question_ids))
          AND (NOT v_has_range OR qq.level_number BETWEEN p_from_level AND p_to_level);
        GET DIAGNOSTICS v_affected = ROW_COUNT;
    ELSIF v_action = 'move_level' THEN
        UPDATE public.quiz_questions qq
        SET level_number = p_target_level,
            cms_revision = v_new_cms,
            updated_at = NOW()
        WHERE qq.category_id = v_cat
          AND (NOT v_has_ids OR qq.id = ANY(p_question_ids))
          AND (NOT v_has_range OR qq.level_number BETWEEN p_from_level AND p_to_level);
        GET DIAGNOSTICS v_affected = ROW_COUNT;
    END IF;

    UPDATE public.quiz_categories qc
    SET total_levels = CASE
            WHEN v_action = 'move_level' AND v_affected > 0 THEN GREATEST(qc.total_levels, p_target_level)
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
        'إجراء جماعي على الأسئلة: ' || v_action,
        jsonb_build_object(
            'action', v_action,
            'affected_count', v_affected,
            'from_level', p_from_level,
            'to_level', p_to_level,
            'target_level', p_target_level,
            'ids_count', COALESCE(array_length(p_question_ids, 1), 0),
            'cms_revision', v_new_cms
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'action', v_action,
        'category_id', v_cat,
        'affected_count', v_affected,
        'pack_needs_republish', COALESCE(v_pack_dirty, FALSE),
        'cms_version', v_new_cms
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_bulk_manage_questions(TEXT, TEXT, TEXT[], INTEGER, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_bulk_manage_questions(TEXT, TEXT, TEXT[], INTEGER, INTEGER, INTEGER) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. `admin_upsert_category_availability`: Open / Coming Soon / Hidden Category
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_upsert_category_availability(
    p_category_id TEXT,
    p_availability_status TEXT,
    p_coming_soon_message TEXT DEFAULT ''
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
    v_status TEXT := LOWER(BTRIM(COALESCE(p_availability_status, '')));
    v_msg TEXT := LEFT(BTRIM(COALESCE(p_coming_soon_message, '')), 180);
    v_new_cms BIGINT;
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_status NOT IN ('open', 'coming_soon', 'hidden') THEN
        RAISE EXCEPTION 'Invalid availability_status: %', v_status;
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    UPDATE public.quiz_categories qc
    SET availability_status = v_status,
        coming_soon_message = CASE WHEN v_status = 'coming_soon' THEN v_msg ELSE '' END,
        is_visible = (v_status <> 'hidden'),
        is_locked = (v_status = 'coming_soon'),
        cms_revision = v_new_cms,
        updated_at = NOW()
    WHERE qc.id = v_cat
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quiz category not found: %', v_cat;
    END IF;

    PERFORM public._write_admin_audit_log(
        'upsert_category_availability',
        'quiz_category',
        v_cat,
        'تحديث حالة توفر القسم: ' || v_status,
        jsonb_build_object(
            'availability_status', v_status,
            'coming_soon_message', v_msg,
            'cms_revision', v_new_cms
        )
    );

    RETURN to_jsonb(v_row) || jsonb_build_object('cms_version', v_new_cms);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_category_availability(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_category_availability(TEXT, TEXT, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. `admin_bulk_set_level_overrides`: Set Level or Level Range Status (0ms Delta)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_bulk_set_level_overrides(
    p_category_id TEXT,
    p_from_level INTEGER,
    p_to_level INTEGER,
    p_status TEXT,
    p_message TEXT DEFAULT ''
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
    v_status TEXT := LOWER(BTRIM(COALESCE(p_status, '')));
    v_msg TEXT := LEFT(BTRIM(COALESCE(p_message, '')), 160);
    v_overrides JSONB;
    v_lvl INTEGER;
    v_new_cms BIGINT;
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF p_from_level IS NULL OR p_to_level IS NULL OR p_from_level < 1 OR p_to_level > 100 OR p_from_level > p_to_level THEN
        RAISE EXCEPTION 'Invalid level range: %..% (must satisfy 1 <= from <= to <= 100)', p_from_level, p_to_level;
    END IF;

    IF v_status NOT IN ('open', 'coming_soon', 'hidden') THEN
        RAISE EXCEPTION 'Invalid level override status: %', v_status;
    END IF;

    SELECT COALESCE(qc.level_overrides, '{}'::jsonb)
    INTO v_overrides
    FROM public.quiz_categories qc
    WHERE qc.id = v_cat
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quiz category not found: %', v_cat;
    END IF;

    FOR v_lvl IN p_from_level..p_to_level LOOP
        IF v_status = 'open' THEN
            v_overrides := v_overrides - v_lvl::TEXT;
        ELSE
            v_overrides := jsonb_set(
                v_overrides,
                ARRAY[v_lvl::TEXT],
                jsonb_build_object(
                    'status', v_status,
                    'message', CASE WHEN v_status = 'coming_soon' THEN v_msg ELSE '' END
                ),
                TRUE
            );
        END IF;
    END LOOP;

    v_new_cms := public._bump_cms_version('android', v_uid);

    UPDATE public.quiz_categories qc
    SET level_overrides = v_overrides,
        cms_revision = v_new_cms,
        updated_at = NOW()
    WHERE qc.id = v_cat
    RETURNING * INTO v_row;

    PERFORM public._write_admin_audit_log(
        'bulk_set_level_overrides',
        'quiz_category',
        v_cat,
        'تحديث حالة المستويات ' || p_from_level || '..' || p_to_level || ' -> ' || v_status,
        jsonb_build_object(
            'from_level', p_from_level,
            'to_level', p_to_level,
            'status', v_status,
            'message', v_msg,
            'cms_revision', v_new_cms
        )
    );

    RETURN to_jsonb(v_row) || jsonb_build_object('cms_version', v_new_cms);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_bulk_set_level_overrides(TEXT, INTEGER, INTEGER, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_bulk_set_level_overrides(TEXT, INTEGER, INTEGER, TEXT, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 6. `admin_toggle_hidden_local_question`: Hide/Show Bundled Local Question by ID
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_toggle_hidden_local_question(
    p_category_id TEXT,
    p_question_id TEXT,
    p_hide BOOLEAN DEFAULT TRUE
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
    v_qid TEXT := BTRIM(COALESCE(p_question_id, ''));
    v_current TEXT[];
    v_next TEXT[];
    v_new_cms BIGINT;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_qid = '' OR LENGTH(v_qid) > 80 THEN
        RAISE EXCEPTION 'Invalid local question id';
    END IF;

    SELECT COALESCE(qc.hidden_local_question_ids, ARRAY[]::TEXT[])
    INTO v_current
    FROM public.quiz_categories qc
    WHERE qc.id = v_cat
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quiz category not found: %', v_cat;
    END IF;

    IF COALESCE(p_hide, TRUE) THEN
        SELECT ARRAY(
            SELECT DISTINCT x
            FROM UNNEST(array_append(v_current, v_qid)) AS x
            WHERE BTRIM(x) <> ''
            ORDER BY x
        ) INTO v_next;
    ELSE
        SELECT ARRAY(
            SELECT x
            FROM UNNEST(v_current) AS x
            WHERE x <> v_qid
            ORDER BY x
        ) INTO v_next;
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    UPDATE public.quiz_categories qc
    SET hidden_local_question_ids = COALESCE(v_next, ARRAY[]::TEXT[]),
        cms_revision = v_new_cms,
        updated_at = NOW()
    WHERE qc.id = v_cat;

    PERFORM public._write_admin_audit_log(
        'toggle_hidden_local_question',
        'quiz_category',
        v_cat,
        CASE WHEN COALESCE(p_hide, TRUE) THEN 'إخفاء سؤال محلي: ' || v_qid ELSE 'إظهار سؤال محلي: ' || v_qid END,
        jsonb_build_object(
            'question_id', v_qid,
            'hidden', COALESCE(p_hide, TRUE),
            'cms_revision', v_new_cms
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'category_id', v_cat,
        'question_id', v_qid,
        'hidden', COALESCE(p_hide, TRUE),
        'hidden_local_question_ids', COALESCE(to_jsonb(v_next), '[]'::jsonb),
        'cms_version', v_new_cms
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_toggle_hidden_local_question(TEXT, TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_toggle_hidden_local_question(TEXT, TEXT, BOOLEAN) TO authenticated, service_role;
