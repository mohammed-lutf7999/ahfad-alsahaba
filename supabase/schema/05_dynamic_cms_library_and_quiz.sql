-- ============================================================================
-- AUTO-GENERATED CANONICAL SCHEMA REFERENCE — DO NOT EDIT MANUALLY!
-- Domain: 05_dynamic_cms_library_and_quiz.sql (المحتوى الديناميكي CMS، المكتبة، بنك الأسئلة، وحزم Gzip CDN)
-- Source: supabase/migrations/001..024 (25 migrations)
-- Generator: python tools/export_supabase_schema.py
-- Summary: 4 tables | 4 RLS policies | 4 indexes | 5 triggers | 24 functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLES & COLUMN/CONSTRAINT EVOLUTION
-- ----------------------------------------------------------------------------

-- Table: public.library_items (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE TABLE IF NOT EXISTS public.library_items (
    id TEXT PRIMARY KEY CHECK (id ~ '^[a-zA-Z0-9_-]{3,80}$'),
    section_id TEXT NOT NULL REFERENCES public.library_sections(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    title TEXT NOT NULL CHECK (LENGTH(BTRIM(title)) >= 2),
    subtitle TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL CHECK (LENGTH(BTRIM(content)) >= 3),
    source_ref TEXT NOT NULL DEFAULT '',
    sort_order INTEGER NOT NULL DEFAULT 100,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    cms_revision BIGINT NOT NULL DEFAULT 1 CHECK (cms_revision >= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.library_items:
--   [016_dynamic_cms_store_and_hardening.sql]
ALTER TABLE public.library_items ENABLE ROW LEVEL SECURITY;

-- Table: public.library_sections (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE TABLE IF NOT EXISTS public.library_sections (
    id TEXT PRIMARY KEY CHECK (id ~ '^[a-z0-9_]{2,48}$'),
    title TEXT NOT NULL CHECK (LENGTH(BTRIM(title)) >= 2),
    icon_name TEXT NOT NULL DEFAULT 'auto_stories_rounded',
    color_hex TEXT NOT NULL DEFAULT '#D4AF37',
    sort_order INTEGER NOT NULL DEFAULT 100,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    cms_revision BIGINT NOT NULL DEFAULT 1 CHECK (cms_revision >= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.library_sections:
--   [016_dynamic_cms_store_and_hardening.sql]
ALTER TABLE public.library_sections ENABLE ROW LEVEL SECURITY;

-- Table: public.quiz_categories (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE TABLE IF NOT EXISTS public.quiz_categories (
    id TEXT PRIMARY KEY CHECK (id ~ '^[a-z0-9_]{2,48}$'),
    name TEXT NOT NULL CHECK (LENGTH(BTRIM(name)) >= 2),
    description TEXT NOT NULL DEFAULT '',
    icon_name TEXT NOT NULL DEFAULT 'quiz_rounded',
    color_hex TEXT NOT NULL DEFAULT '#1B5E20',
    total_levels INTEGER NOT NULL DEFAULT 10 CHECK (total_levels BETWEEN 1 AND 100),
    sort_order INTEGER NOT NULL DEFAULT 100,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    cms_revision BIGINT NOT NULL DEFAULT 1 CHECK (cms_revision >= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.quiz_categories:
--   [016_dynamic_cms_store_and_hardening.sql]
ALTER TABLE public.quiz_categories ENABLE ROW LEVEL SECURITY;
--   [023_dynamic_levels_and_gzip_question_packs.sql]
ALTER TABLE public.quiz_categories
    ADD COLUMN IF NOT EXISTS questions_per_level INTEGER NOT NULL DEFAULT 10
        CHECK (questions_per_level BETWEEN 1 AND 100),
    ADD COLUMN IF NOT EXISTS level_draw_mode TEXT NOT NULL DEFAULT 'fixed'
        CHECK (level_draw_mode IN ('fixed', 'rotating_pool')),
    ADD COLUMN IF NOT EXISTS pack_version INTEGER NOT NULL DEFAULT 0
        CHECK (pack_version >= 0),
    ADD COLUMN IF NOT EXISTS pack_storage_path TEXT NOT NULL DEFAULT '';
--   [024a_level_question_management_schema_and_security.sql]
ALTER TABLE public.quiz_categories
    ADD COLUMN IF NOT EXISTS availability_status TEXT NOT NULL DEFAULT 'open',
    ADD COLUMN IF NOT EXISTS coming_soon_message TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS level_overrides JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS hidden_local_question_ids TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN IF NOT EXISTS questions_updated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS pack_published_at TIMESTAMPTZ;
--   [024a_level_question_management_schema_and_security.sql]
ALTER TABLE public.quiz_categories
            ADD CONSTRAINT chk_quiz_categories_availability_status
            CHECK (availability_status IN ('open', 'coming_soon', 'hidden'));

-- Table: public.quiz_questions (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE TABLE IF NOT EXISTS public.quiz_questions (
    id TEXT PRIMARY KEY CHECK (id ~ '^[a-zA-Z0-9_-]{3,80}$'),
    category_id TEXT NOT NULL REFERENCES public.quiz_categories(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    level_number INTEGER NOT NULL CHECK (level_number BETWEEN 1 AND 100),
    question_text TEXT NOT NULL CHECK (LENGTH(BTRIM(question_text)) >= 3),
    options JSONB NOT NULL CHECK (jsonb_typeof(options) = 'array' AND jsonb_array_length(options) = 4),
    correct_index INTEGER NOT NULL CHECK (correct_index BETWEEN 0 AND 3),
    explanation TEXT NOT NULL DEFAULT '',
    sync_scope TEXT NOT NULL DEFAULT 'solo_only' CHECK (sync_scope IN ('solo_only', 'all_with_fallback')),
    sort_order INTEGER NOT NULL DEFAULT 100,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    cms_revision BIGINT NOT NULL DEFAULT 1 CHECK (cms_revision >= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.quiz_questions:
--   [016_dynamic_cms_store_and_hardening.sql]
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. ACTIVE RLS POLICIES
-- ----------------------------------------------------------------------------

-- Policy: "Read visible library items" ON public.library_items (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE POLICY "Read visible library items"
ON public.library_items
FOR SELECT
USING (is_visible = TRUE OR public.check_is_admin());

-- Policy: "Read visible library sections" ON public.library_sections (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE POLICY "Read visible library sections"
ON public.library_sections
FOR SELECT
USING (is_visible = TRUE OR public.check_is_admin());

-- Policy: "Read visible quiz categories" ON public.quiz_categories (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE POLICY "Read visible quiz categories"
ON public.quiz_categories
FOR SELECT
USING (is_visible = TRUE OR public.check_is_admin());

-- Policy: "Read visible quiz questions" ON public.quiz_questions (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE POLICY "Read visible quiz questions"
ON public.quiz_questions
FOR SELECT
USING (is_visible = TRUE OR public.check_is_admin());

-- ----------------------------------------------------------------------------
-- 3. ACTIVE INDEXES
-- ----------------------------------------------------------------------------

-- Index: idx_library_items_section ON public.library_items (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE INDEX IF NOT EXISTS idx_library_items_section ON public.library_items (section_id, sort_order, cms_revision);

-- Index: idx_library_sections_cms ON public.library_sections (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE INDEX IF NOT EXISTS idx_library_sections_cms ON public.library_sections (cms_revision, sort_order);

-- Index: idx_quiz_categories_cms ON public.quiz_categories (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE INDEX IF NOT EXISTS idx_quiz_categories_cms ON public.quiz_categories (cms_revision, sort_order);

-- Index: idx_quiz_questions_cat_lvl ON public.quiz_questions (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE INDEX IF NOT EXISTS idx_quiz_questions_cat_lvl ON public.quiz_questions (category_id, level_number, sort_order, cms_revision);

-- ----------------------------------------------------------------------------
-- 4. ACTIVE TRIGGERS
-- ----------------------------------------------------------------------------

-- Trigger: trg_library_items_cms_rev ON public.library_items (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE TRIGGER trg_library_items_cms_rev
BEFORE INSERT OR UPDATE ON public.library_items
FOR EACH ROW EXECUTE FUNCTION public.trg_fn_cms_auto_revision();

-- Trigger: trg_library_sections_cms_rev ON public.library_sections (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE TRIGGER trg_library_sections_cms_rev
BEFORE INSERT OR UPDATE ON public.library_sections
FOR EACH ROW EXECUTE FUNCTION public.trg_fn_cms_auto_revision();

-- Trigger: trg_quiz_categories_cms_rev ON public.quiz_categories (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE TRIGGER trg_quiz_categories_cms_rev
BEFORE INSERT OR UPDATE ON public.quiz_categories
FOR EACH ROW EXECUTE FUNCTION public.trg_fn_cms_auto_revision();

-- Trigger: trg_quiz_questions_cms_rev ON public.quiz_questions (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE TRIGGER trg_quiz_questions_cms_rev
BEFORE INSERT OR UPDATE ON public.quiz_questions
FOR EACH ROW EXECUTE FUNCTION public.trg_fn_cms_auto_revision();

-- Trigger: trg_quiz_questions_touch_category_ts ON public.quiz_questions (latest: 024a_level_question_management_schema_and_security.sql)
CREATE TRIGGER trg_quiz_questions_touch_category_ts
AFTER INSERT OR UPDATE OR DELETE ON public.quiz_questions
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_quiz_questions_touch_updated_at();

-- ----------------------------------------------------------------------------
-- 5. LATEST EFFECTIVE FUNCTIONS & RPCs
-- ----------------------------------------------------------------------------

-- Function: public._bump_cms_version | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public._bump_cms_version(
    p_platform TEXT DEFAULT 'android',
    p_admin_id UUID DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_platform TEXT := COALESCE(NULLIF(LOWER(BTRIM(p_platform)), ''), 'android');
    v_new_cms BIGINT;
BEGIN
    INSERT INTO public.app_release_config (platform, updated_by, config_version, cms_version)
    VALUES (v_platform, p_admin_id, 1, 1)
    ON CONFLICT (platform) DO NOTHING;

    UPDATE public.app_release_config cfg
    SET cms_version = COALESCE(cfg.cms_version, 1) + 1,
        updated_at = NOW(),
        updated_by = COALESCE(p_admin_id, cfg.updated_by)
    WHERE cfg.platform = v_platform
    RETURNING cfg.cms_version INTO v_new_cms;

    RETURN COALESCE(v_new_cms, 1);
END;
$$;
-- Effective permission history for public._bump_cms_version:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public._bump_cms_version(TEXT, UUID) FROM PUBLIC, anon, authenticated;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public._bump_cms_version(TEXT, UUID) TO service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public._bump_cms_version FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_browse_quiz_questions | latest: 024b_level_question_management_admin_rpcs.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_browse_quiz_questions:
--   [024b_level_question_management_admin_rpcs.sql] REVOKE ALL ON FUNCTION public.admin_browse_quiz_questions(TEXT, INTEGER, TEXT, TEXT, INTEGER, INTEGER) FROM PUBLIC, anon;
--   [024b_level_question_management_admin_rpcs.sql] GRANT EXECUTE ON FUNCTION public.admin_browse_quiz_questions(TEXT, INTEGER, TEXT, TEXT, INTEGER, INTEGER) TO authenticated, service_role;

-- Function: public.admin_bulk_manage_questions | latest: 024b_level_question_management_admin_rpcs.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_bulk_manage_questions:
--   [024b_level_question_management_admin_rpcs.sql] REVOKE ALL ON FUNCTION public.admin_bulk_manage_questions(TEXT, TEXT, TEXT[], INTEGER, INTEGER, INTEGER) FROM PUBLIC, anon;
--   [024b_level_question_management_admin_rpcs.sql] GRANT EXECUTE ON FUNCTION public.admin_bulk_manage_questions(TEXT, TEXT, TEXT[], INTEGER, INTEGER, INTEGER) TO authenticated, service_role;

-- Function: public.admin_bulk_set_level_overrides | latest: 024b_level_question_management_admin_rpcs.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_bulk_set_level_overrides:
--   [024b_level_question_management_admin_rpcs.sql] REVOKE ALL ON FUNCTION public.admin_bulk_set_level_overrides(TEXT, INTEGER, INTEGER, TEXT, TEXT) FROM PUBLIC, anon;
--   [024b_level_question_management_admin_rpcs.sql] GRANT EXECUTE ON FUNCTION public.admin_bulk_set_level_overrides(TEXT, INTEGER, INTEGER, TEXT, TEXT) TO authenticated, service_role;

-- Function: public.admin_bulk_upsert_quiz_questions | latest: 023_dynamic_levels_and_gzip_question_packs.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_bulk_upsert_quiz_questions:
--   [023_dynamic_levels_and_gzip_question_packs.sql] REVOKE ALL ON FUNCTION public.admin_bulk_upsert_quiz_questions(TEXT, JSONB) FROM PUBLIC, anon;
--   [023_dynamic_levels_and_gzip_question_packs.sql] GRANT EXECUTE ON FUNCTION public.admin_bulk_upsert_quiz_questions(TEXT, JSONB) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_bulk_upsert_quiz_questions FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_delete_quiz_question | latest: 024b_level_question_management_admin_rpcs.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_delete_quiz_question:
--   [024b_level_question_management_admin_rpcs.sql] REVOKE ALL ON FUNCTION public.admin_delete_quiz_question(TEXT) FROM PUBLIC, anon;
--   [024b_level_question_management_admin_rpcs.sql] GRANT EXECUTE ON FUNCTION public.admin_delete_quiz_question(TEXT) TO authenticated, service_role;

-- Function: public.admin_export_category_pack_payload | latest: 024a_level_question_management_schema_and_security.sql | redefinitions: 2 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_export_category_pack_payload:
--   [023_dynamic_levels_and_gzip_question_packs.sql] REVOKE ALL ON FUNCTION public.admin_export_category_pack_payload(TEXT) FROM PUBLIC, anon;
--   [023_dynamic_levels_and_gzip_question_packs.sql] GRANT EXECUTE ON FUNCTION public.admin_export_category_pack_payload(TEXT) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_export_category_pack_payload(TEXT) FROM PUBLIC, anon;
--   [024a_level_question_management_schema_and_security.sql] GRANT EXECUTE ON FUNCTION public.admin_export_category_pack_payload(TEXT) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_export_category_pack_payload FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_list_library_content | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_list_library_content(
    p_section_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_sec TEXT := NULLIF(LOWER(BTRIM(COALESCE(p_section_id, ''))), '');
    v_sections JSONB := '[]'::jsonb;
    v_items JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            to_jsonb(ls) || jsonb_build_object(
                'items_count', (SELECT COUNT(*) FROM public.library_items li WHERE li.section_id = ls.id)
            )
            ORDER BY ls.sort_order, ls.id
        ),
        '[]'::jsonb
    )
    INTO v_sections
    FROM public.library_sections ls;

    SELECT COALESCE(
        jsonb_agg(to_jsonb(li) ORDER BY li.section_id, li.sort_order, li.created_at DESC),
        '[]'::jsonb
    )
    INTO v_items
    FROM public.library_items li
    WHERE v_sec IS NULL OR li.section_id = v_sec;

    RETURN jsonb_build_object(
        'sections', v_sections,
        'items', v_items
    );
END;
$$;
-- Effective permission history for public.admin_list_library_content:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_list_library_content(TEXT) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_list_library_content(TEXT) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_list_library_content FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_list_quiz_content | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_list_quiz_content(
    p_category_id TEXT DEFAULT NULL,
    p_level_number INTEGER DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_cat TEXT := NULLIF(LOWER(BTRIM(COALESCE(p_category_id, ''))), '');
    v_limit INTEGER := GREATEST(1, LEAST(250, COALESCE(p_limit, 100)));
    v_cats JSONB := '[]'::jsonb;
    v_questions JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            to_jsonb(qc) || jsonb_build_object(
                'custom_questions_count', (SELECT COUNT(*) FROM public.quiz_questions qq WHERE qq.category_id = qc.id)
            )
            ORDER BY qc.sort_order, qc.id
        ),
        '[]'::jsonb
    )
    INTO v_cats
    FROM public.quiz_categories qc;

    SELECT COALESCE(jsonb_agg(to_jsonb(sub)), '[]'::jsonb)
    INTO v_questions
    FROM (
        SELECT qq.*
        FROM public.quiz_questions qq
        WHERE (v_cat IS NULL OR qq.category_id = v_cat)
          AND (p_level_number IS NULL OR qq.level_number = p_level_number)
        ORDER BY qq.category_id, qq.level_number, qq.sort_order, qq.created_at DESC
        LIMIT v_limit
    ) sub;

    RETURN jsonb_build_object(
        'categories', v_cats,
        'questions', v_questions
    );
END;
$$;
-- Effective permission history for public.admin_list_quiz_content:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_list_quiz_content(TEXT, INTEGER, INTEGER) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_list_quiz_content(TEXT, INTEGER, INTEGER) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_list_quiz_content FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_list_store_items | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_list_store_items()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_rows JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            to_jsonb(s) || jsonb_build_object(
                'owners_count', (
                    SELECT COUNT(*) FROM public.user_inventory ui WHERE ui.item_id = s.id
                )
            )
            ORDER BY s.category, s.sort_order, s.min_level, s.id
        ),
        '[]'::jsonb
    )
    INTO v_rows
    FROM public.store_items s;

    RETURN v_rows;
END;
$$;
-- Effective permission history for public.admin_list_store_items:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_list_store_items() FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_list_store_items() TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_list_store_items FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_publish_category_pack | latest: 024a_level_question_management_schema_and_security.sql | redefinitions: 2 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_publish_category_pack:
--   [023_dynamic_levels_and_gzip_question_packs.sql] REVOKE ALL ON FUNCTION public.admin_publish_category_pack(TEXT, TEXT, INTEGER) FROM PUBLIC, anon;
--   [023_dynamic_levels_and_gzip_question_packs.sql] GRANT EXECUTE ON FUNCTION public.admin_publish_category_pack(TEXT, TEXT, INTEGER) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_publish_category_pack(TEXT, TEXT, INTEGER) FROM PUBLIC, anon;
--   [024a_level_question_management_schema_and_security.sql] GRANT EXECUTE ON FUNCTION public.admin_publish_category_pack(TEXT, TEXT, INTEGER) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_publish_category_pack FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_set_content_visibility | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
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
        SET is_visible = v_visible, cms_revision = v_new_cms, updated_at = NOW()
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
        CASE WHEN v_visible THEN 'show_content' ELSE 'hide_content' END,
        v_type,
        v_id,
        'تبديل حالة الظهور والإخفاء',
        jsonb_build_object('is_visible', v_visible, 'cms_revision', v_new_cms)
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'entity_type', v_type,
        'id', v_id,
        'is_visible', v_visible,
        'cms_version', v_new_cms
    );
END;
$$;
-- Effective permission history for public.admin_set_content_visibility:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_set_content_visibility(TEXT, TEXT, BOOLEAN) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_set_content_visibility(TEXT, TEXT, BOOLEAN) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_set_content_visibility FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_toggle_hidden_local_question | latest: 024b_level_question_management_admin_rpcs.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_toggle_hidden_local_question:
--   [024b_level_question_management_admin_rpcs.sql] REVOKE ALL ON FUNCTION public.admin_toggle_hidden_local_question(TEXT, TEXT, BOOLEAN) FROM PUBLIC, anon;
--   [024b_level_question_management_admin_rpcs.sql] GRANT EXECUTE ON FUNCTION public.admin_toggle_hidden_local_question(TEXT, TEXT, BOOLEAN) TO authenticated, service_role;

-- Function: public.admin_update_quiz_category_config | latest: 023_dynamic_levels_and_gzip_question_packs.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_update_quiz_category_config:
--   [023_dynamic_levels_and_gzip_question_packs.sql] REVOKE ALL ON FUNCTION public.admin_update_quiz_category_config(TEXT, INTEGER, INTEGER, TEXT) FROM PUBLIC, anon;
--   [023_dynamic_levels_and_gzip_question_packs.sql] GRANT EXECUTE ON FUNCTION public.admin_update_quiz_category_config(TEXT, INTEGER, INTEGER, TEXT) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_update_quiz_category_config FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_upsert_category_availability | latest: 024b_level_question_management_admin_rpcs.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_upsert_category_availability:
--   [024b_level_question_management_admin_rpcs.sql] REVOKE ALL ON FUNCTION public.admin_upsert_category_availability(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
--   [024b_level_question_management_admin_rpcs.sql] GRANT EXECUTE ON FUNCTION public.admin_upsert_category_availability(TEXT, TEXT, TEXT) TO authenticated, service_role;

-- Function: public.admin_upsert_library_item | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_upsert_library_item(
    p_id TEXT DEFAULT NULL,
    p_section_id TEXT DEFAULT 'stories',
    p_title TEXT DEFAULT '',
    p_subtitle TEXT DEFAULT '',
    p_content TEXT DEFAULT '',
    p_source_ref TEXT DEFAULT '',
    p_sort_order INTEGER DEFAULT 100,
    p_is_visible BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_id TEXT := NULLIF(BTRIM(COALESCE(p_id, '')), '');
    v_sec TEXT := LOWER(BTRIM(COALESCE(p_section_id, '')));
    v_title TEXT := BTRIM(COALESCE(p_title, ''));
    v_sub TEXT := BTRIM(COALESCE(p_subtitle, ''));
    v_content TEXT := BTRIM(COALESCE(p_content, ''));
    v_src TEXT := BTRIM(COALESCE(p_source_ref, ''));
    v_sort INTEGER := COALESCE(p_sort_order, 100);
    v_visible BOOLEAN := COALESCE(p_is_visible, TRUE);
    v_new_cms BIGINT;
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_id IS NULL THEN
        v_id := 'lib_' || REPLACE(gen_random_uuid()::text, '-', '');
    ELSIF v_id !~ '^[a-zA-Z0-9_-]{3,80}$' THEN
        RAISE EXCEPTION 'Invalid library item id';
    END IF;

    IF v_title = '' OR LENGTH(v_content) < 3 THEN
        RAISE EXCEPTION 'Library item title and content are required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.library_sections ls WHERE ls.id = v_sec) THEN
        RAISE EXCEPTION 'Library section (%) does not exist', v_sec;
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    INSERT INTO public.library_items (
        id, section_id, title, subtitle, content, source_ref, sort_order, is_visible, cms_revision, updated_at
    )
    VALUES (
        v_id, v_sec, v_title, v_sub, v_content, v_src, v_sort, v_visible, v_new_cms, NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET section_id = EXCLUDED.section_id,
        title = EXCLUDED.title,
        subtitle = EXCLUDED.subtitle,
        content = EXCLUDED.content,
        source_ref = EXCLUDED.source_ref,
        sort_order = EXCLUDED.sort_order,
        is_visible = EXCLUDED.is_visible,
        cms_revision = v_new_cms,
        updated_at = NOW()
    RETURNING * INTO v_row;

    PERFORM public._write_admin_audit_log(
        'upsert_library_item', 'library_item', v_id, 'إدارة مادة مكتبة',
        jsonb_build_object('section_id', v_sec, 'is_visible', v_visible, 'cms_revision', v_new_cms)
    );

    RETURN to_jsonb(v_row) || jsonb_build_object('cms_version', v_new_cms);
END;
$$;
-- Effective permission history for public.admin_upsert_library_item:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_upsert_library_item(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_upsert_library_item(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_upsert_library_item FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_upsert_library_section | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_upsert_library_section(
    p_id TEXT,
    p_title TEXT,
    p_icon_name TEXT DEFAULT 'auto_stories_rounded',
    p_color_hex TEXT DEFAULT '#D4AF37',
    p_sort_order INTEGER DEFAULT 100,
    p_is_visible BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_id TEXT := LOWER(BTRIM(COALESCE(p_id, '')));
    v_title TEXT := BTRIM(COALESCE(p_title, ''));
    v_icon TEXT := COALESCE(NULLIF(BTRIM(p_icon_name), ''), 'auto_stories_rounded');
    v_color TEXT := COALESCE(NULLIF(UPPER(BTRIM(p_color_hex)), ''), '#D4AF37');
    v_sort INTEGER := COALESCE(p_sort_order, 100);
    v_visible BOOLEAN := COALESCE(p_is_visible, TRUE);
    v_new_cms BIGINT;
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_id !~ '^[a-z0-9_]{2,48}$' THEN
        RAISE EXCEPTION 'Invalid library section id';
    END IF;
    IF v_title = '' THEN
        RAISE EXCEPTION 'Library section title cannot be empty';
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    INSERT INTO public.library_sections (
        id, title, icon_name, color_hex, sort_order, is_visible, cms_revision, updated_at
    )
    VALUES (
        v_id, v_title, v_icon, v_color, v_sort, v_visible, v_new_cms, NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET title = EXCLUDED.title,
        icon_name = EXCLUDED.icon_name,
        color_hex = EXCLUDED.color_hex,
        sort_order = EXCLUDED.sort_order,
        is_visible = EXCLUDED.is_visible,
        cms_revision = v_new_cms,
        updated_at = NOW()
    RETURNING * INTO v_row;

    PERFORM public._write_admin_audit_log(
        'upsert_library_section', 'library_section', v_id, 'إدارة قسم مكتبة',
        jsonb_build_object('is_visible', v_visible, 'cms_revision', v_new_cms)
    );

    RETURN to_jsonb(v_row) || jsonb_build_object('cms_version', v_new_cms);
END;
$$;
-- Effective permission history for public.admin_upsert_library_section:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_upsert_library_section(TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_upsert_library_section(TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_upsert_library_section FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_upsert_quiz_category | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_upsert_quiz_category(
    p_id TEXT,
    p_name TEXT,
    p_description TEXT DEFAULT '',
    p_icon_name TEXT DEFAULT 'quiz_rounded',
    p_color_hex TEXT DEFAULT '#1B5E20',
    p_total_levels INTEGER DEFAULT 10,
    p_sort_order INTEGER DEFAULT 100,
    p_is_visible BOOLEAN DEFAULT TRUE,
    p_is_locked BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_id TEXT := LOWER(BTRIM(COALESCE(p_id, '')));
    v_name TEXT := BTRIM(COALESCE(p_name, ''));
    v_desc TEXT := BTRIM(COALESCE(p_description, ''));
    v_icon TEXT := COALESCE(NULLIF(BTRIM(p_icon_name), ''), 'quiz_rounded');
    v_color TEXT := COALESCE(NULLIF(UPPER(BTRIM(p_color_hex)), ''), '#1B5E20');
    v_levels INTEGER := GREATEST(1, LEAST(100, COALESCE(p_total_levels, 10)));
    v_sort INTEGER := COALESCE(p_sort_order, 100);
    v_visible BOOLEAN := COALESCE(p_is_visible, TRUE);
    v_locked BOOLEAN := COALESCE(p_is_locked, FALSE);
    v_new_cms BIGINT;
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_id !~ '^[a-z0-9_]{2,48}$' THEN
        RAISE EXCEPTION 'Invalid quiz category id';
    END IF;
    IF v_name = '' THEN
        RAISE EXCEPTION 'Quiz category name cannot be empty';
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    INSERT INTO public.quiz_categories (
        id, name, description, icon_name, color_hex, total_levels,
        sort_order, is_visible, is_locked, cms_revision, updated_at
    )
    VALUES (
        v_id, v_name, v_desc, v_icon, v_color, v_levels,
        v_sort, v_visible, v_locked, v_new_cms, NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET name = EXCLUDED.name,
        description = EXCLUDED.description,
        icon_name = EXCLUDED.icon_name,
        color_hex = EXCLUDED.color_hex,
        total_levels = EXCLUDED.total_levels,
        sort_order = EXCLUDED.sort_order,
        is_visible = EXCLUDED.is_visible,
        is_locked = EXCLUDED.is_locked,
        cms_revision = v_new_cms,
        updated_at = NOW()
    RETURNING * INTO v_row;

    PERFORM public._write_admin_audit_log(
        'upsert_quiz_category', 'quiz_category', v_id, 'إدارة قسم مسابقات',
        jsonb_build_object('total_levels', v_levels, 'is_visible', v_visible, 'cms_revision', v_new_cms)
    );

    RETURN to_jsonb(v_row) || jsonb_build_object('cms_version', v_new_cms);
END;
$$;
-- Effective permission history for public.admin_upsert_quiz_category:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_upsert_quiz_category(TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, BOOLEAN, BOOLEAN) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_upsert_quiz_category(TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, BOOLEAN, BOOLEAN) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_upsert_quiz_category FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_upsert_quiz_question | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_upsert_quiz_question(
    p_id TEXT DEFAULT NULL,
    p_category_id TEXT DEFAULT 'quran',
    p_level_number INTEGER DEFAULT 1,
    p_question_text TEXT DEFAULT '',
    p_options JSONB DEFAULT '[]'::jsonb,
    p_correct_index INTEGER DEFAULT 0,
    p_explanation TEXT DEFAULT '',
    p_sync_scope TEXT DEFAULT 'solo_only',
    p_sort_order INTEGER DEFAULT 100,
    p_is_visible BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_id TEXT := NULLIF(BTRIM(COALESCE(p_id, '')), '');
    v_cat TEXT := LOWER(BTRIM(COALESCE(p_category_id, '')));
    v_level INTEGER := GREATEST(1, LEAST(100, COALESCE(p_level_number, 1)));
    v_qtext TEXT := BTRIM(COALESCE(p_question_text, ''));
    v_correct INTEGER := COALESCE(p_correct_index, 0);
    v_exp TEXT := BTRIM(COALESCE(p_explanation, ''));
    v_scope TEXT := LOWER(BTRIM(COALESCE(p_sync_scope, 'solo_only')));
    v_sort INTEGER := COALESCE(p_sort_order, 100);
    v_visible BOOLEAN := COALESCE(p_is_visible, TRUE);
    v_cat_max_levels INTEGER;
    v_new_cms BIGINT;
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_id IS NULL THEN
        v_id := 'cq_' || REPLACE(gen_random_uuid()::text, '-', '');
    ELSIF v_id !~ '^[a-zA-Z0-9_-]{3,80}$' THEN
        RAISE EXCEPTION 'Invalid question id';
    END IF;

    IF LENGTH(v_qtext) < 3 THEN
        RAISE EXCEPTION 'Question text is too short';
    END IF;

    IF p_options IS NULL OR jsonb_typeof(p_options) <> 'array' OR jsonb_array_length(p_options) <> 4 THEN
        RAISE EXCEPTION 'Question must provide exactly 4 options';
    END IF;

    IF EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(p_options) AS opt(val)
        WHERE LENGTH(BTRIM(COALESCE(opt.val, ''))) = 0
    ) THEN
        RAISE EXCEPTION 'All 4 options must be non-empty';
    END IF;

    IF v_correct NOT BETWEEN 0 AND 3 THEN
        RAISE EXCEPTION 'correct_index must be between 0 and 3';
    END IF;

    IF v_scope NOT IN ('solo_only', 'all_with_fallback') THEN
        v_scope := 'solo_only';
    END IF;

    SELECT qc.total_levels INTO v_cat_max_levels
    FROM public.quiz_categories qc
    WHERE qc.id = v_cat;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quiz category (%) does not exist', v_cat;
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    -- Auto-expand category total_levels if admin adds a question at level > current total_levels
    IF v_level > v_cat_max_levels THEN
        UPDATE public.quiz_categories qc
        SET total_levels = v_level,
            cms_revision = v_new_cms,
            updated_at = NOW()
        WHERE qc.id = v_cat;
    END IF;

    INSERT INTO public.quiz_questions (
        id, category_id, level_number, question_text, options, correct_index,
        explanation, sync_scope, sort_order, is_visible, cms_revision, updated_at
    )
    VALUES (
        v_id, v_cat, v_level, v_qtext, p_options, v_correct,
        v_exp, v_scope, v_sort, v_visible, v_new_cms, NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET category_id = EXCLUDED.category_id,
        level_number = EXCLUDED.level_number,
        question_text = EXCLUDED.question_text,
        options = EXCLUDED.options,
        correct_index = EXCLUDED.correct_index,
        explanation = EXCLUDED.explanation,
        sync_scope = EXCLUDED.sync_scope,
        sort_order = EXCLUDED.sort_order,
        is_visible = EXCLUDED.is_visible,
        cms_revision = v_new_cms,
        updated_at = NOW()
    RETURNING * INTO v_row;

    PERFORM public._write_admin_audit_log(
        'upsert_quiz_question', 'quiz_question', v_id, 'إدارة سؤال مسابقة',
        jsonb_build_object('category_id', v_cat, 'level_number', v_level, 'is_visible', v_visible, 'cms_revision', v_new_cms)
    );

    RETURN to_jsonb(v_row) || jsonb_build_object('cms_version', v_new_cms);
END;
$$;
-- Effective permission history for public.admin_upsert_quiz_question:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_upsert_quiz_question(TEXT, TEXT, INTEGER, TEXT, JSONB, INTEGER, TEXT, TEXT, INTEGER, BOOLEAN) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_upsert_quiz_question(TEXT, TEXT, INTEGER, TEXT, JSONB, INTEGER, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_upsert_quiz_question FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_upsert_store_item | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_upsert_store_item(
    p_id TEXT,
    p_title TEXT,
    p_description TEXT DEFAULT '',
    p_category TEXT DEFAULT 'title',
    p_price_coins INTEGER DEFAULT 0,
    p_price_gems INTEGER DEFAULT 0,
    p_min_level INTEGER DEFAULT 1,
    p_asset_key TEXT DEFAULT '',
    p_is_visible BOOLEAN DEFAULT TRUE,
    p_sort_order INTEGER DEFAULT 100,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_id TEXT := LOWER(BTRIM(COALESCE(p_id, '')));
    v_title TEXT := BTRIM(COALESCE(p_title, ''));
    v_desc TEXT := BTRIM(COALESCE(p_description, ''));
    v_cat TEXT := LOWER(BTRIM(COALESCE(p_category, 'title')));
    v_asset TEXT := BTRIM(COALESCE(p_asset_key, ''));
    v_coins INTEGER := GREATEST(0, LEAST(1000000, COALESCE(p_price_coins, 0)));
    v_gems INTEGER := GREATEST(0, LEAST(100000, COALESCE(p_price_gems, 0)));
    v_min_lvl INTEGER := GREATEST(1, LEAST(100, COALESCE(p_min_level, 1)));
    v_visible BOOLEAN := COALESCE(p_is_visible, TRUE);
    v_sort INTEGER := COALESCE(p_sort_order, 100);
    v_meta JSONB := COALESCE(p_metadata, '{}'::jsonb);
    v_new_cms BIGINT;
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_id !~ '^[a-z0-9_]{3,64}$' THEN
        RAISE EXCEPTION 'Invalid store item id (use 3..64 lowercase letters, digits, or _)';
    END IF;

    IF v_title = '' THEN
        RAISE EXCEPTION 'Store item title cannot be empty';
    END IF;

    IF v_cat NOT IN ('theme', 'frame', 'title', 'powerup') THEN
        RAISE EXCEPTION 'Invalid category: %', v_cat;
    END IF;

    IF v_asset = '' THEN
        v_asset := CASE WHEN v_cat = 'title' THEN v_title ELSE v_id END;
    END IF;

    v_new_cms := public._bump_cms_version('android', v_uid);

    INSERT INTO public.store_items (
        id, title, description, category, price_coins, price_gems, min_level,
        asset_key, is_visible, sort_order, metadata, cms_revision, updated_at
    )
    VALUES (
        v_id, v_title, v_desc, v_cat, v_coins, v_gems, v_min_lvl,
        v_asset, v_visible, v_sort, v_meta, v_new_cms, NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET title = EXCLUDED.title,
        description = EXCLUDED.description,
        category = EXCLUDED.category,
        price_coins = EXCLUDED.price_coins,
        price_gems = EXCLUDED.price_gems,
        min_level = EXCLUDED.min_level,
        asset_key = EXCLUDED.asset_key,
        is_visible = EXCLUDED.is_visible,
        sort_order = EXCLUDED.sort_order,
        metadata = EXCLUDED.metadata,
        cms_revision = v_new_cms,
        updated_at = NOW()
    RETURNING * INTO v_row;

    PERFORM public._write_admin_audit_log(
        'upsert_store_item',
        'store_item',
        v_id,
        'تحديث عنصر متجر الفرسان',
        jsonb_build_object('category', v_cat, 'is_visible', v_visible, 'price_coins', v_coins, 'price_gems', v_gems, 'cms_revision', v_new_cms)
    );

    RETURN to_jsonb(v_row) || jsonb_build_object('cms_version', v_new_cms);
END;
$$;
-- Effective permission history for public.admin_upsert_store_item:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_upsert_store_item(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, TEXT, BOOLEAN, INTEGER, JSONB) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_upsert_store_item(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, TEXT, BOOLEAN, INTEGER, JSONB) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_upsert_store_item FROM PUBLIC, anon; -- via DO block

-- Function: public.get_cms_bundle | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.get_cms_bundle(
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

    SELECT COALESCE(jsonb_agg(to_jsonb(qc) ORDER BY qc.sort_order, qc.id), '[]'::jsonb)
    INTO v_quiz_cats
    FROM public.quiz_categories qc
    WHERE (v_is_incremental AND qc.cms_revision > v_client_ver)
       OR (NOT v_is_incremental AND qc.is_visible = TRUE);

    SELECT COALESCE(jsonb_agg(to_jsonb(qq) ORDER BY qq.category_id, qq.level_number, qq.sort_order, qq.id), '[]'::jsonb)
    INTO v_quiz_questions
    FROM public.quiz_questions qq
    WHERE (v_is_incremental AND qq.cms_revision > v_client_ver)
       OR (NOT v_is_incremental AND qq.is_visible = TRUE);

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
-- Effective permission history for public.get_cms_bundle:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.get_cms_bundle(BIGINT, TEXT[]) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.get_cms_bundle(BIGINT, TEXT[]) TO anon, authenticated, service_role;

-- Function: public.get_cms_bundle_v2 | latest: 024a_level_question_management_schema_and_security.sql | redefinitions: 2 | security_definer: True | search_path: True
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
-- Effective permission history for public.get_cms_bundle_v2:
--   [023_dynamic_levels_and_gzip_question_packs.sql] REVOKE ALL ON FUNCTION public.get_cms_bundle_v2(BIGINT, TEXT[]) FROM PUBLIC;
--   [023_dynamic_levels_and_gzip_question_packs.sql] GRANT EXECUTE ON FUNCTION public.get_cms_bundle_v2(BIGINT, TEXT[]) TO anon, authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.get_cms_bundle_v2(BIGINT, TEXT[]) FROM PUBLIC;
--   [024a_level_question_management_schema_and_security.sql] GRANT EXECUTE ON FUNCTION public.get_cms_bundle_v2(BIGINT, TEXT[]) TO anon, authenticated, service_role;

-- Function: public.trg_fn_cms_auto_revision | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.trg_fn_cms_auto_revision()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_txn_cms TEXT;
    v_cur_cfg_cms BIGINT := 1;
    v_new_cms BIGINT;
BEGIN
    NEW.updated_at := NOW();

    -- 1. If an admin_* RPC updated cms_revision cleanly on UPDATE, honor it as-is.
    IF TG_OP = 'UPDATE' AND NEW.cms_revision IS DISTINCT FROM OLD.cms_revision THEN
        RETURN NEW;
    END IF;

    -- 2. Check current cms_version on app_release_config.
    SELECT COALESCE(cfg.cms_version, 1)
    INTO v_cur_cfg_cms
    FROM public.app_release_config cfg
    WHERE cfg.platform = 'android'
    LIMIT 1;
    v_cur_cfg_cms := COALESCE(v_cur_cfg_cms, 1);

    -- 3. On INSERT where an admin_* RPC already bumped cfg.cms_version and passed it in:
    IF TG_OP = 'INSERT'
       AND COALESCE(NEW.cms_revision, 1) > 1
       AND COALESCE(NEW.cms_revision, 1) >= v_cur_cfg_cms THEN
        RETURN NEW;
    END IF;

    -- 4. Reuse one version bump across a bulk manual edit transaction.
    v_txn_cms := NULLIF(current_setting('app.cms_auto_bumped_ver', TRUE), '');
    IF v_txn_cms IS NOT NULL THEN
        NEW.cms_revision := v_txn_cms::bigint;
        RETURN NEW;
    END IF;

    v_new_cms := public._bump_cms_version('android', auth.uid());
    PERFORM set_config('app.cms_auto_bumped_ver', v_new_cms::text, TRUE);
    NEW.cms_revision := v_new_cms;
    RETURN NEW;
END;
$$;

-- Function: public.trg_fn_quiz_questions_touch_updated_at | latest: 024a_level_question_management_schema_and_security.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.trg_fn_quiz_questions_touch_updated_at:
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.trg_fn_quiz_questions_touch_updated_at() FROM PUBLIC, anon, authenticated;
--   [024a_level_question_management_schema_and_security.sql] GRANT EXECUTE ON FUNCTION public.trg_fn_quiz_questions_touch_updated_at() TO service_role;
