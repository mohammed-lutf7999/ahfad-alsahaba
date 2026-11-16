-- ==============================================================================
-- MIGRATION 016: DYNAMIC HYBRID CMS, SAFE VISIBILITY, STORE SECURITY HARDENING,
-- PLAYER INSPECTOR & COMPENSATION GUARDS, GHOST MONITOR & ADMIN AUDIT LOGS
-- ==============================================================================
-- Highlights:
-- 1. Hardens `purchase_store_item` (auth.uid() check, is_visible check, search_path)
--    and protects owned inventory from hard deletes (`trg_guard_store_item_delete`).
-- 2. Updates `trg_fn_sync_user_progress_level` and `trg_fn_sync_leaderboard_glory`
--    so any dynamic title in `store_items` works seamlessly (removing hardcoded list).
-- 3. Expands `store_items` with `is_visible`, `sort_order`, `metadata`, `cms_revision`.
-- 4. Adds RLS-protected CMS tables:
--      `library_sections`, `library_items`, `quiz_categories`, `quiz_questions`
--    with non-destructive visibility (`is_visible`), versioned delta (`cms_revision`),
--    and online compatibility guard (`sync_scope`).
-- 5. Adds `admin_audit_logs` + `cms_version` on `app_release_config`.
-- 6. Adds zero-bloat `get_cms_bundle(client_cms_version, owned_item_ids)` and embeds
--    `cms_version` inside `get_app_control_state` (<100B short-circuit preserved).
-- 7. Adds strictly `check_is_admin()` (and owner-only `app_admins`) RPCs including
--    capped `admin_grant_player_compensation` (max 10,000 coins / 100 gems / 5,000 XP).
-- ==============================================================================

-- ==============================================================================
-- 1. OWNER & AUDIT HELPERS + AUDIT LOG TABLE
-- ==============================================================================

CREATE OR REPLACE FUNCTION public._current_actor_email()
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_email TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RETURN '';
    END IF;

    SELECT LOWER(BTRIM(COALESCE(u.email, '')))
    INTO v_email
    FROM auth.users u
    WHERE u.id = v_uid
    LIMIT 1;

    RETURN COALESCE(v_email, '');
END;
$$;

REVOKE ALL ON FUNCTION public._current_actor_email() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._current_actor_email() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public._check_is_owner()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_email TEXT := public._current_actor_email();
BEGIN
    IF v_email = '' THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.app_admins aa
        WHERE LOWER(aa.email) = v_email
          AND LOWER(aa.role) = 'owner'
    );
END;
$$;

REVOKE ALL ON FUNCTION public._check_is_owner() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._check_is_owner() TO authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    admin_email TEXT NOT NULL DEFAULT '',
    action TEXT NOT NULL CHECK (LENGTH(BTRIM(action)) >= 2),
    target_type TEXT NOT NULL DEFAULT '',
    target_id TEXT NOT NULL DEFAULT '',
    reason TEXT NOT NULL DEFAULT '',
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created
    ON public.admin_audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target
    ON public.admin_audit_logs (target_type, target_id, created_at DESC);

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins read audit logs" ON public.admin_audit_logs;
CREATE POLICY "Admins read audit logs"
ON public.admin_audit_logs
FOR SELECT
TO authenticated
USING (public.check_is_admin());

CREATE OR REPLACE FUNCTION public._write_admin_audit_log(
    p_action TEXT,
    p_target_type TEXT DEFAULT '',
    p_target_id TEXT DEFAULT '',
    p_reason TEXT DEFAULT '',
    p_details JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
BEGIN
    INSERT INTO public.admin_audit_logs (
        admin_user_id,
        admin_email,
        action,
        target_type,
        target_id,
        reason,
        details
    )
    VALUES (
        auth.uid(),
        public._current_actor_email(),
        BTRIM(COALESCE(p_action, 'unknown')),
        BTRIM(COALESCE(p_target_type, '')),
        BTRIM(COALESCE(p_target_id, '')),
        BTRIM(COALESCE(p_reason, '')),
        COALESCE(p_details, '{}'::jsonb)
    );
END;
$$;

REVOKE ALL ON FUNCTION public._write_admin_audit_log(TEXT, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._write_admin_audit_log(TEXT, TEXT, TEXT, TEXT, JSONB) TO service_role;

-- ==============================================================================
-- 2. CMS VERSION TRACKING ON `app_release_config`
-- ==============================================================================

ALTER TABLE public.app_release_config
    ADD COLUMN IF NOT EXISTS cms_version BIGINT NOT NULL DEFAULT 1 CHECK (cms_version >= 1);

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

REVOKE ALL ON FUNCTION public._bump_cms_version(TEXT, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._bump_cms_version(TEXT, UUID) TO service_role;

-- ==============================================================================
-- 3. STORE HARDENING: `store_items` VISIBILITY/METADATA, OWNERSHIP GUARD,
--    TRIGGERS & `purchase_store_item` SECURITY FIX
-- ==============================================================================

ALTER TABLE public.store_items
    ADD COLUMN IF NOT EXISTS is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 100,
    ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS cms_revision BIGINT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_store_items_visible_sort
    ON public.store_items (is_visible, category, sort_order, min_level, id);

DROP POLICY IF EXISTS "Public read store_items" ON public.store_items;
DROP POLICY IF EXISTS "Visible or owned read store_items" ON public.store_items;
CREATE POLICY "Visible or owned read store_items"
ON public.store_items
FOR SELECT
USING (
    is_visible = TRUE
    OR public.check_is_admin()
    OR (
        auth.uid() IS NOT NULL
        AND EXISTS (
            SELECT 1
            FROM public.user_inventory ui
            WHERE ui.user_id = auth.uid()
              AND ui.item_id = store_items.id
        )
    )
);

CREATE OR REPLACE FUNCTION public.trg_fn_guard_store_item_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.user_inventory ui
        WHERE ui.item_id = OLD.id
    ) THEN
        RAISE EXCEPTION 'Cannot delete store item (%) because players own it; set is_visible = FALSE instead', OLD.id;
    END IF;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_store_item_delete ON public.store_items;
CREATE TRIGGER trg_guard_store_item_delete
BEFORE DELETE ON public.store_items
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_guard_store_item_delete();

-- Backfill rich metadata & sort_order cleanly for existing 20 catalog rows only if empty
UPDATE public.store_items SET sort_order = 10, metadata = '{"deepBackground":"#0D061A","surfaceCard":"#24143D","sovereignAccent":"#F3C644","secondaryAccent":"#D4AF37","previewColor":"#F3C644","iconName":"palette_rounded"}'::jsonb WHERE id = 'theme_andalusian_gold' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 20, metadata = '{"deepBackground":"#05140E","surfaceCard":"#14382A","sovereignAccent":"#E9B872","secondaryAccent":"#52B788","previewColor":"#52B788","iconName":"park_rounded"}'::jsonb WHERE id = 'theme_emerald_banner' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 30, metadata = '{"deepBackground":"#060B19","surfaceCard":"#12234D","sovereignAccent":"#38BDF8","secondaryAccent":"#93C5FD","previewColor":"#38BDF8","iconName":"nights_stay_rounded"}'::jsonb WHERE id = 'theme_badr_meteors' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 40, metadata = '{"deepBackground":"#120409","surfaceCard":"#340E1E","sovereignAccent":"#F59E0B","secondaryAccent":"#F43F5E","previewColor":"#F43F5E","iconName":"local_fire_department_rounded"}'::jsonb WHERE id = 'theme_yarmouk_carnelian' AND metadata = '{}'::jsonb;

UPDATE public.store_items SET sort_order = 10, metadata = '{"primaryColor":"#78350F","secondaryColor":"#B45309","highlightColor":"#FDE68A","hasOctagonalStar":false,"hasCornerGems":false,"hasCrownCrest":false,"strokeRatio":0.075,"previewColor":"#A16207"}'::jsonb WHERE id = 'item_frame_wood' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 20, metadata = '{"primaryColor":"#9A3412","secondaryColor":"#D97706","highlightColor":"#FED7AA","hasOctagonalStar":false,"hasCornerGems":true,"hasCrownCrest":false,"strokeRatio":0.08,"previewColor":"#D97706"}'::jsonb WHERE id = 'item_frame_copper' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 30, metadata = '{"primaryColor":"#92400E","secondaryColor":"#F59E0B","highlightColor":"#FEF3C7","hasOctagonalStar":true,"hasCornerGems":false,"hasCrownCrest":false,"strokeRatio":0.085,"previewColor":"#B45309"}'::jsonb WHERE id = 'item_frame_bronze' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 40, metadata = '{"primaryColor":"#475569","secondaryColor":"#CBD5E1","highlightColor":"#FFFFFF","hasOctagonalStar":true,"hasCornerGems":true,"hasCrownCrest":false,"strokeRatio":0.088,"previewColor":"#E2E8F0"}'::jsonb WHERE id = 'item_frame_silver' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 50, metadata = '{"primaryColor":"#B45309","secondaryColor":"#F3C644","highlightColor":"#FFFBEB","hasOctagonalStar":true,"hasCornerGems":true,"hasCrownCrest":false,"strokeRatio":0.092,"previewColor":"#F3C644"}'::jsonb WHERE id = 'item_frame_gold' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 60, metadata = '{"primaryColor":"#065F46","secondaryColor":"#10B981","highlightColor":"#A7F3D0","hasOctagonalStar":true,"hasCornerGems":true,"hasCrownCrest":false,"strokeRatio":0.095,"previewColor":"#10B981"}'::jsonb WHERE id = 'item_frame_emerald' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 70, metadata = '{"primaryColor":"#9F1239","secondaryColor":"#F43F5E","highlightColor":"#FECDD3","hasOctagonalStar":true,"hasCornerGems":true,"hasCrownCrest":true,"strokeRatio":0.098,"previewColor":"#E11D48"}'::jsonb WHERE id = 'item_frame_ruby' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 80, metadata = '{"primaryColor":"#1E40AF","secondaryColor":"#38BDF8","highlightColor":"#E0F2FE","hasOctagonalStar":true,"hasCornerGems":true,"hasCrownCrest":true,"strokeRatio":0.10,"previewColor":"#2563EB"}'::jsonb WHERE id = 'item_frame_sapphire' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 90, metadata = '{"primaryColor":"#5B21B6","secondaryColor":"#C084FC","highlightColor":"#FAF5FF","hasOctagonalStar":true,"hasCornerGems":true,"hasCrownCrest":true,"strokeRatio":0.105,"previewColor":"#8B5CF6"}'::jsonb WHERE id = 'item_frame_platinum' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 100, metadata = '{"primaryColor":"#0284C7","secondaryColor":"#38BDF8","highlightColor":"#FFFFFF","hasOctagonalStar":true,"hasCornerGems":true,"hasCrownCrest":true,"strokeRatio":0.11,"previewColor":"#38BDF8"}'::jsonb WHERE id = 'item_frame_diamond' AND metadata = '{}'::jsonb;

UPDATE public.store_items SET sort_order = 10, metadata = '{"previewColor":"#F59E0B","iconName":"workspace_premium_rounded"}'::jsonb WHERE id = 'title_saqr_quraish' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 20, metadata = '{"previewColor":"#10B981","iconName":"security_rounded"}'::jsonb WHERE id = 'title_dira_qadisiyah' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 30, metadata = '{"previewColor":"#38BDF8","iconName":"auto_awesome_rounded"}'::jsonb WHERE id = 'title_hakiim_zaman' AND metadata = '{}'::jsonb;

UPDATE public.store_items SET sort_order = 10, metadata = '{"previewColor":"#38BDF8","iconName":"health_and_safety_rounded"}'::jsonb WHERE id = 'powerup_shield' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 20, metadata = '{"previewColor":"#FBBF24","iconName":"lightbulb_rounded"}'::jsonb WHERE id = 'powerup_insight' AND metadata = '{}'::jsonb;
UPDATE public.store_items SET sort_order = 30, metadata = '{"previewColor":"#A78BFA","iconName":"bolt_rounded"}'::jsonb WHERE id = 'powerup_xp_banner' AND metadata = '{}'::jsonb;

-- Update live level/leaderboard triggers to validate titles dynamically from `store_items`
CREATE OR REPLACE FUNCTION public.trg_fn_sync_user_progress_level()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_calc RECORD;
    v_old_lvl INT := COALESCE(OLD.player_level, 1);
    v_lvl_step INT;
    v_coins_bonus INT := 0;
BEGIN
    SELECT * INTO v_calc FROM public.calculate_level_and_title(NEW.total_score);
    NEW.player_level := v_calc.out_level;
    IF NEW.player_title IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.store_items s
        WHERE s.category = 'title' AND s.asset_key = NEW.player_title
    ) THEN
        NEW.player_title := v_calc.out_title;
    END IF;
    NEW.current_level_xp := v_calc.out_cur_xp;
    NEW.next_level_xp := v_calc.out_next_xp;

    IF v_calc.out_level > v_old_lvl THEN
        FOR v_lvl_step IN (v_old_lvl + 1)..v_calc.out_level LOOP
            v_coins_bonus := v_coins_bonus + (v_lvl_step * 50);
        END LOOP;
        NEW.coins := COALESCE(NEW.coins, 100) + v_coins_bonus;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_fn_sync_leaderboard_glory()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_calc RECORD;
BEGIN
    NEW.trophies := GREATEST(800, COALESCE(NEW.trophies, 1000));

    SELECT * INTO v_calc FROM public.calculate_level_and_title(NEW.score);
    NEW.player_level := v_calc.out_level;
    IF NEW.player_title IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.store_items s
        WHERE s.category = 'title' AND s.asset_key = NEW.player_title
    ) THEN
        NEW.player_title := v_calc.out_title;
    END IF;

    IF NEW.trophies >= 1850 THEN
        NEW.arena_id := 6; NEW.arena_name := 'ميدان الفتوحات العظمى';
    ELSIF NEW.trophies >= 1600 THEN
        NEW.arena_id := 5; NEW.arena_name := 'ميدان عمورية';
    ELSIF NEW.trophies >= 1400 THEN
        NEW.arena_id := 4; NEW.arena_name := 'ميدان القادسية';
    ELSIF NEW.trophies >= 1200 THEN
        NEW.arena_id := 3; NEW.arena_name := 'ميدان اليرموك';
    ELSIF NEW.trophies >= 1000 THEN
        NEW.arena_id := 2; NEW.arena_name := 'ميدان بدر الكبرى';
    ELSE
        NEW.arena_id := 1; NEW.arena_name := 'ميدان يثرب';
    END IF;

    RETURN NEW;
END;
$$;

-- Hardened `purchase_store_item` (auth.uid() match + visibility check + row lock)
CREATE OR REPLACE FUNCTION public.purchase_store_item(p_user_id UUID, p_item_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_item RECORD;
    v_user RECORD;
BEGIN
    IF v_uid IS NULL OR p_user_id IS NULL OR v_uid <> p_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'غير مصرح بإتمام الشراء إلا لصاحب الحساب');
    END IF;

    SELECT * INTO v_item
    FROM public.store_items s
    WHERE s.id = p_item_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'العنصر غير موجود في المتجر');
    END IF;

    IF NOT COALESCE(v_item.is_visible, TRUE) THEN
        RETURN jsonb_build_object('success', false, 'error', 'هذا العنصر مخفي حالياً عن الشراء');
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.user_inventory ui
        WHERE ui.user_id = v_uid AND ui.item_id = p_item_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'تمتلك هذا العنصر مسبقاً');
    END IF;

    SELECT up.coins, up.gems, up.player_level
    INTO v_user
    FROM public.user_progress up
    WHERE up.user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'لم يتم العثور على ملف تقدم اللاعب');
    END IF;

    IF COALESCE(v_user.player_level, 1) < COALESCE(v_item.min_level, 1) THEN
        RETURN jsonb_build_object('success', false, 'error', 'مستواك الحالي أقل من المستوى المطلوب');
    END IF;

    IF COALESCE(v_user.coins, 0) < COALESCE(v_item.price_coins, 0)
       OR COALESCE(v_user.gems, 0) < COALESCE(v_item.price_gems, 0) THEN
        RETURN jsonb_build_object('success', false, 'error', 'رصيد الدنانير أو الياقوت غير كافٍ');
    END IF;

    UPDATE public.user_progress up
    SET coins = COALESCE(up.coins, 0) - COALESCE(v_item.price_coins, 0),
        gems = COALESCE(up.gems, 0) - COALESCE(v_item.price_gems, 0),
        updated_at = NOW()
    WHERE up.user_id = v_uid;

    INSERT INTO public.user_inventory (user_id, item_id)
    VALUES (v_uid, p_item_id);

    RETURN jsonb_build_object(
        'success', true,
        'remaining_coins', COALESCE(v_user.coins, 0) - COALESCE(v_item.price_coins, 0),
        'remaining_gems', COALESCE(v_user.gems, 0) - COALESCE(v_item.price_gems, 0)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.purchase_store_item(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purchase_store_item(UUID, TEXT) TO authenticated, service_role;

-- ==============================================================================
-- 4. DYNAMIC LIBRARY & QUIZ TABLES + STRICT RLS + DEFAULT SEEDS
-- ==============================================================================

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

CREATE INDEX IF NOT EXISTS idx_library_sections_cms ON public.library_sections (cms_revision, sort_order);
CREATE INDEX IF NOT EXISTS idx_library_items_section ON public.library_items (section_id, sort_order, cms_revision);

ALTER TABLE public.library_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.library_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read visible library sections" ON public.library_sections;
CREATE POLICY "Read visible library sections"
ON public.library_sections
FOR SELECT
USING (is_visible = TRUE OR public.check_is_admin());

DROP POLICY IF EXISTS "Read visible library items" ON public.library_items;
CREATE POLICY "Read visible library items"
ON public.library_items
FOR SELECT
USING (is_visible = TRUE OR public.check_is_admin());

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

CREATE INDEX IF NOT EXISTS idx_quiz_categories_cms ON public.quiz_categories (cms_revision, sort_order);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_cat_lvl ON public.quiz_questions (category_id, level_number, sort_order, cms_revision);

ALTER TABLE public.quiz_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read visible quiz categories" ON public.quiz_categories;
CREATE POLICY "Read visible quiz categories"
ON public.quiz_categories
FOR SELECT
USING (is_visible = TRUE OR public.check_is_admin());

DROP POLICY IF EXISTS "Read visible quiz questions" ON public.quiz_questions;
CREATE POLICY "Read visible quiz questions"
ON public.quiz_questions
FOR SELECT
USING (is_visible = TRUE OR public.check_is_admin());

-- Seed existing 7 library sections & 6 quiz categories non-destructively
INSERT INTO public.library_sections (id, title, icon_name, color_hex, sort_order, is_visible, cms_revision)
VALUES
    ('stories', 'قصص وعبر', 'auto_stories_rounded', '#D4AF37', 10, TRUE, 1),
    ('azkar', 'الأذكار', 'nights_stay_rounded', '#38BDF8', 20, TRUE, 1),
    ('duas', 'أدعية مستجابة', 'volunteer_activism_rounded', '#10B981', 30, TRUE, 1),
    ('hadith', 'الحديث الشريف', 'format_quote_rounded', '#F59E0B', 40, TRUE, 1),
    ('wisdom', 'حكم وأقوال', 'lightbulb_rounded', '#A78BFA', 50, TRUE, 1),
    ('jokes', 'طرائف عربية', 'emoji_emotions_rounded', '#FB7185', 60, TRUE, 1),
    ('quran', 'القرآن الكريم', 'menu_book_rounded', '#22C55E', 70, TRUE, 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.quiz_categories (id, name, description, icon_name, color_hex, total_levels, sort_order, is_visible, is_locked, cms_revision)
VALUES
    ('quran', 'القرآن الكريم', 'أسئلة عن القرآن الكريم وعلومه', 'menu_book_rounded', '#1B5E20', 10, 10, TRUE, FALSE, 1),
    ('hadith', 'الحديث الشريف', 'أسئلة في السنة النبوية وعلوم الحديث', 'format_quote_rounded', '#0D47A1', 10, 20, TRUE, FALSE, 1),
    ('fiqh', 'الفقه الإسلامي', 'أسئلة في أحكام العبادات والمعاملات', 'balance_rounded', '#4A148C', 10, 30, TRUE, FALSE, 1),
    ('seerah', 'السيرة النبوية', 'أحداث السيرة النبوية وغزواتها ومواقفها', 'mosque_rounded', '#B45309', 10, 40, TRUE, FALSE, 1),
    ('history', 'التاريخ الإسلامي', 'تاريخ الخلفاء والفتوحات والحضارة الإسلامية', 'account_balance_rounded', '#004D40', 10, 50, TRUE, FALSE, 1),
    ('aqeedah', 'العقيدة الإسلامية', 'أصول الإيمان والتوحيد ومنهج أهل السنة', 'stars_rounded', '#880E4F', 10, 60, TRUE, FALSE, 1)
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- 5. UPGRADED `get_app_control_state` (INCLUDES `cms_version` ON TINY DELTA)
--    AND NEW `get_cms_bundle(p_client_cms_version, p_owned_item_ids)`
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_app_control_state(
    p_platform TEXT DEFAULT 'android',
    p_version_code INTEGER DEFAULT 0,
    p_client_config_version BIGINT DEFAULT 0,
    p_player_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_platform TEXT := COALESCE(NULLIF(LOWER(BTRIM(p_platform)), ''), 'android');
    v_uid UUID := auth.uid();
    v_is_admin BOOLEAN := public.check_is_admin();
    v_raw_code TEXT := UPPER(BTRIM(COALESCE(p_player_code, '')));
    v_valid_code TEXT := NULL;
    v_config RECORD;
    v_active_event JSONB := NULL;
    v_personal_announcements JSONB := '[]'::jsonb;
    v_all_announcements JSONB := '[]'::jsonb;
    v_force_update BOOLEAN := FALSE;
    v_optional_update BOOLEAN := FALSE;
BEGIN
    IF v_raw_code ~ '^SAH-[A-Z0-9]{4,8}$' AND LENGTH(v_raw_code) BETWEEN 8 AND 12 THEN
        v_valid_code := v_raw_code;
    END IF;

    SELECT
        cfg.platform,
        cfg.min_version_code,
        cfg.latest_version_code,
        cfg.latest_version_name,
        cfg.update_title,
        cfg.update_message,
        cfg.update_url,
        cfg.maintenance_mode,
        cfg.maintenance_title,
        cfg.maintenance_message,
        cfg.feature_flags,
        cfg.config_version,
        cfg.cms_version,
        cfg.updated_at
    INTO v_config
    FROM public.app_release_config cfg
    WHERE cfg.platform = v_platform
    LIMIT 1;

    IF NOT FOUND THEN
        SELECT
            cfg.platform,
            cfg.min_version_code,
            cfg.latest_version_code,
            cfg.latest_version_name,
            cfg.update_title,
            cfg.update_message,
            cfg.update_url,
            cfg.maintenance_mode,
            cfg.maintenance_title,
            cfg.maintenance_message,
            cfg.feature_flags,
            cfg.config_version,
            cfg.cms_version,
            cfg.updated_at
        INTO v_config
        FROM public.app_release_config cfg
        WHERE cfg.platform = 'android'
        LIMIT 1;
    END IF;

    SELECT COALESCE(
        jsonb_agg(to_jsonb(t) ORDER BY t.is_mandatory_rank ASC, t.created_at DESC),
        '[]'::jsonb
    )
    INTO v_personal_announcements
    FROM (
        SELECT
            ann.id,
            ann.title,
            ann.body,
            ann.message_type,
            ann.target_scope,
            ann.target_user_id,
            ann.target_player_code,
            ann.cta_label,
            ann.cta_route,
            ann.is_dismissible,
            ann.min_version_code,
            ann.max_version_code,
            ann.expires_at,
            ann.created_at,
            CASE WHEN ann.message_type = 'mandatory' THEN 0 ELSE 1 END AS is_mandatory_rank
        FROM public.admin_announcements ann
        WHERE ann.is_active = TRUE
          AND ann.target_scope = 'single_user'
          AND (ann.starts_at IS NULL OR ann.starts_at <= NOW())
          AND (ann.expires_at IS NULL OR ann.expires_at > NOW())
          AND (
              COALESCE(p_version_code, 0) <= 0
              OR (
                  (ann.min_version_code IS NULL OR p_version_code >= ann.min_version_code)
                  AND (ann.max_version_code IS NULL OR p_version_code <= ann.max_version_code)
              )
          )
          AND (
              (v_uid IS NOT NULL AND ann.target_user_id = v_uid)
              OR (v_valid_code IS NOT NULL AND ann.target_player_code = v_valid_code)
          )
          AND NOT EXISTS (
              SELECT 1
              FROM public.user_announcement_receipts rec
              WHERE rec.announcement_id = ann.id
                AND (
                    (v_uid IS NOT NULL AND (rec.recipient_key = ('uid:' || v_uid::text) OR rec.user_id = v_uid))
                    OR (v_valid_code IS NOT NULL AND (rec.recipient_key = ('code:' || v_valid_code) OR rec.player_code = v_valid_code))
                )
          )
        ORDER BY CASE WHEN ann.message_type = 'mandatory' THEN 0 ELSE 1 END ASC, ann.created_at DESC
        LIMIT 5
    ) t;

    IF COALESCE(p_client_config_version, 0) > 0
       AND COALESCE(v_config.config_version, 1) = p_client_config_version
       AND jsonb_array_length(v_personal_announcements) = 0 THEN
        RETURN jsonb_build_object(
            'changed', FALSE,
            'config_version', COALESCE(v_config.config_version, 1),
            'cms_version', COALESCE(v_config.cms_version, 1),
            'is_admin', v_is_admin,
            'server_time', NOW()
        );
    END IF;

    IF COALESCE(p_version_code, 0) > 0 AND v_config IS NOT NULL THEN
        v_force_update := (p_version_code < v_config.min_version_code);
        v_optional_update := (NOT v_force_update AND p_version_code < v_config.latest_version_code);
    END IF;

    SELECT jsonb_build_object(
        'id', ev.id,
        'badge_text', ev.badge_text,
        'title', ev.title,
        'subtitle', ev.subtitle,
        'body', ev.body,
        'cta_label', ev.cta_label,
        'action_type', ev.action_type,
        'action_target', ev.action_target,
        'theme_color_hex', ev.theme_color_hex,
        'icon_name', ev.icon_name,
        'priority', ev.priority,
        'starts_at', ev.starts_at,
        'ends_at', ev.ends_at,
        'updated_at', ev.updated_at
    )
    INTO v_active_event
    FROM public.app_dynamic_events ev
    WHERE ev.is_active = TRUE
      AND (ev.ends_at IS NULL OR ev.ends_at > NOW())
    ORDER BY
        CASE WHEN ev.starts_at IS NULL OR ev.starts_at <= NOW() THEN 0 ELSE 1 END ASC,
        ev.priority DESC,
        ev.updated_at DESC
    LIMIT 1;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', comb.id,
                'title', comb.title,
                'body', comb.body,
                'message_type', comb.message_type,
                'target_scope', comb.target_scope,
                'target_user_id', comb.target_user_id,
                'target_player_code', comb.target_player_code,
                'cta_label', comb.cta_label,
                'cta_route', comb.cta_route,
                'is_dismissible', comb.is_dismissible,
                'min_version_code', comb.min_version_code,
                'max_version_code', comb.max_version_code,
                'expires_at', comb.expires_at,
                'created_at', comb.created_at
            )
            ORDER BY comb.scope_rank ASC, comb.mandatory_rank ASC, comb.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_all_announcements
    FROM (
        SELECT
            ann.id,
            ann.title,
            ann.body,
            ann.message_type,
            ann.target_scope,
            ann.target_user_id,
            ann.target_player_code,
            ann.cta_label,
            ann.cta_route,
            ann.is_dismissible,
            ann.min_version_code,
            ann.max_version_code,
            ann.expires_at,
            ann.created_at,
            CASE WHEN ann.target_scope = 'single_user' THEN 0 ELSE 1 END AS scope_rank,
            CASE WHEN ann.message_type = 'mandatory' THEN 0 ELSE 1 END AS mandatory_rank
        FROM public.admin_announcements ann
        WHERE ann.is_active = TRUE
          AND (ann.starts_at IS NULL OR ann.starts_at <= NOW())
          AND (ann.expires_at IS NULL OR ann.expires_at > NOW())
          AND (
              COALESCE(p_version_code, 0) <= 0
              OR (
                  (ann.min_version_code IS NULL OR p_version_code >= ann.min_version_code)
                  AND (ann.max_version_code IS NULL OR p_version_code <= ann.max_version_code)
              )
          )
          AND (
              ann.target_scope = 'all'
              OR (
                  ann.target_scope = 'single_user'
                  AND (
                      (v_uid IS NOT NULL AND ann.target_user_id = v_uid)
                      OR (v_valid_code IS NOT NULL AND ann.target_player_code = v_valid_code)
                  )
              )
          )
          AND NOT EXISTS (
              SELECT 1
              FROM public.user_announcement_receipts rec
              WHERE rec.announcement_id = ann.id
                AND (
                    (v_uid IS NOT NULL AND (rec.recipient_key = ('uid:' || v_uid::text) OR rec.user_id = v_uid))
                    OR (v_valid_code IS NOT NULL AND (rec.recipient_key = ('code:' || v_valid_code) OR rec.player_code = v_valid_code))
                )
          )
        ORDER BY
            CASE WHEN ann.target_scope = 'single_user' THEN 0 ELSE 1 END ASC,
            CASE WHEN ann.message_type = 'mandatory' THEN 0 ELSE 1 END ASC,
            ann.created_at DESC
        LIMIT 10
    ) comb;

    RETURN jsonb_build_object(
        'changed', TRUE,
        'config_version', COALESCE(v_config.config_version, 1),
        'cms_version', COALESCE(v_config.cms_version, 1),
        'is_admin', v_is_admin,
        'server_time', NOW(),
        'release_config', jsonb_build_object(
            'platform', COALESCE(v_config.platform, 'android'),
            'min_version_code', COALESCE(v_config.min_version_code, 1),
            'latest_version_code', COALESCE(v_config.latest_version_code, 19),
            'latest_version_name', COALESCE(v_config.latest_version_name, '1.0.18'),
            'update_title', COALESCE(v_config.update_title, 'تحديث جديد متاح'),
            'update_message', COALESCE(v_config.update_message, ''),
            'update_url', COALESCE(v_config.update_url, 'https://play.google.com/store/apps/details?id=com.ahfad.alsahaba.battle'),
            'maintenance_mode', COALESCE(v_config.maintenance_mode, FALSE),
            'maintenance_title', COALESCE(v_config.maintenance_title, 'صيانة وتحسينات مؤقتة'),
            'maintenance_message', COALESCE(v_config.maintenance_message, ''),
            'feature_flags', COALESCE(v_config.feature_flags, '{}'::jsonb),
            'config_version', COALESCE(v_config.config_version, 1),
            'cms_version', COALESCE(v_config.cms_version, 1),
            'force_update', v_force_update,
            'optional_update', v_optional_update,
            'updated_at', v_config.updated_at
        ),
        'active_event', v_active_event,
        'announcements', v_all_announcements
    );
END;
$$;

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

REVOKE ALL ON FUNCTION public.get_cms_bundle(BIGINT, TEXT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_cms_bundle(BIGINT, TEXT[]) TO anon, authenticated, service_role;

-- ==============================================================================
-- 6. UPGRADED `admin_get_overview()` + STORE/CONTENT/PLAYER/GHOST/ADMIN RPCS
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_get_overview()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_total_accounts INTEGER := 0;
    v_directory_players INTEGER := 0;
    v_guest_players INTEGER := 0;
    v_active_24h INTEGER := 0;
    v_active_events INTEGER := 0;
    v_active_announcements INTEGER := 0;
    v_store_items_count INTEGER := 0;
    v_library_items_count INTEGER := 0;
    v_quiz_questions_count INTEGER := 0;
    v_total_ghosts INTEGER := 0;
    v_active_ghosts INTEGER := 0;
    v_human_ghosts INTEGER := 0;
    v_version_breakdown JSONB := '[]'::jsonb;
    v_release_config JSONB := '{}'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COUNT(*) INTO v_total_accounts FROM public.leaderboard lb;
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE pd.user_id IS NULL),
        COUNT(*) FILTER (WHERE pd.last_seen_at >= NOW() - INTERVAL '24 hours')
    INTO v_directory_players, v_guest_players, v_active_24h
    FROM public.player_directory pd;

    SELECT COALESCE(jsonb_agg(to_jsonb(vb) ORDER BY vb.version_code DESC), '[]'::jsonb)
    INTO v_version_breakdown
    FROM (
        SELECT
            pd.version_code,
            MAX(pd.app_version) AS app_version,
            COUNT(*) AS players_count
        FROM public.player_directory pd
        GROUP BY pd.version_code
    ) vb;

    SELECT COUNT(*)
    INTO v_active_events
    FROM public.app_dynamic_events ev
    WHERE ev.is_active = TRUE
      AND (ev.ends_at IS NULL OR ev.ends_at > NOW());

    SELECT COUNT(*)
    INTO v_active_announcements
    FROM public.admin_announcements ann
    WHERE ann.is_active = TRUE
      AND (ann.expires_at IS NULL OR ann.expires_at > NOW());

    SELECT COUNT(*) INTO v_store_items_count FROM public.store_items s;
    SELECT COUNT(*) INTO v_library_items_count FROM public.library_items li;
    SELECT COUNT(*) INTO v_quiz_questions_count FROM public.quiz_questions qq;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE gr.is_active = TRUE),
        COUNT(*) FILTER (WHERE gr.user_id IS NOT NULL)
    INTO v_total_ghosts, v_active_ghosts, v_human_ghosts
    FROM public.ghost_recordings gr;

    SELECT to_jsonb(cfg)
    INTO v_release_config
    FROM public.app_release_config cfg
    WHERE cfg.platform = 'android'
    LIMIT 1;

    RETURN jsonb_build_object(
        'total_accounts', v_total_accounts,
        'directory_players', v_directory_players,
        'guest_players', v_guest_players,
        'active_24h', v_active_24h,
        'active_events', v_active_events,
        'active_announcements', v_active_announcements,
        'cms_version', COALESCE((v_release_config->>'cms_version')::BIGINT, 1),
        'store_items_count', v_store_items_count,
        'library_items_count', v_library_items_count,
        'quiz_questions_count', v_quiz_questions_count,
        'total_ghosts', v_total_ghosts,
        'active_ghosts', v_active_ghosts,
        'human_ghosts', v_human_ghosts,
        'version_breakdown', v_version_breakdown,
        'release_config', COALESCE(v_release_config, '{}'::jsonb)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_overview() TO authenticated, service_role;

-- ---- Store CMS RPCs ----

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

REVOKE ALL ON FUNCTION public.admin_list_store_items() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_store_items() TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.admin_upsert_store_item(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, TEXT, BOOLEAN, INTEGER, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_store_item(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, TEXT, BOOLEAN, INTEGER, JSONB) TO authenticated, service_role;

-- ---- Unified Show / Hide Visibility Toggle ----

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

REVOKE ALL ON FUNCTION public.admin_set_content_visibility(TEXT, TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_content_visibility(TEXT, TEXT, BOOLEAN) TO authenticated, service_role;

-- ---- Library CMS RPCs ----

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

REVOKE ALL ON FUNCTION public.admin_list_library_content(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_library_content(TEXT) TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.admin_upsert_library_section(TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_library_section(TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.admin_upsert_library_item(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_library_item(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated, service_role;

-- ---- Quiz CMS RPCs ----

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

REVOKE ALL ON FUNCTION public.admin_list_quiz_content(TEXT, INTEGER, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_quiz_content(TEXT, INTEGER, INTEGER) TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.admin_upsert_quiz_category(TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, BOOLEAN, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_quiz_category(TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, BOOLEAN, BOOLEAN) TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.admin_upsert_quiz_question(TEXT, TEXT, INTEGER, TEXT, JSONB, INTEGER, TEXT, TEXT, INTEGER, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_quiz_question(TEXT, TEXT, INTEGER, TEXT, JSONB, INTEGER, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated, service_role;

-- ---- Player Inspector & Capped Compensations ----

CREATE OR REPLACE FUNCTION public.admin_get_player_detail(
    p_user_id UUID DEFAULT NULL,
    p_player_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_code TEXT := NULLIF(UPPER(BTRIM(COALESCE(p_player_code, ''))), '');
    v_uid UUID := p_user_id;
    v_dir JSONB := NULL;
    v_prog JSONB := NULL;
    v_lb JSONB := NULL;
    v_inventory JSONB := '[]'::jsonb;
    v_matches JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_uid IS NULL AND v_code IS NULL THEN
        RAISE EXCEPTION 'Provide p_user_id or p_player_code';
    END IF;

    IF v_uid IS NULL AND v_code IS NOT NULL THEN
        SELECT pd.user_id INTO v_uid
        FROM public.player_directory pd
        WHERE pd.player_code = v_code
        LIMIT 1;
    END IF;

    SELECT to_jsonb(pd)
    INTO v_dir
    FROM public.player_directory pd
    WHERE (v_uid IS NOT NULL AND pd.user_id = v_uid)
       OR (v_code IS NOT NULL AND pd.player_code = v_code)
    LIMIT 1;

    IF v_uid IS NOT NULL THEN
        SELECT to_jsonb(up)
        INTO v_prog
        FROM public.user_progress up
        WHERE up.user_id = v_uid
        LIMIT 1;

        SELECT to_jsonb(lb)
        INTO v_lb
        FROM public.leaderboard lb
        WHERE lb.user_id = v_uid
        LIMIT 1;

        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'item_id', ui.item_id,
                    'purchased_at', ui.purchased_at,
                    'title', COALESCE(s.title, ui.item_id),
                    'category', s.category,
                    'is_visible', COALESCE(s.is_visible, TRUE)
                )
                ORDER BY ui.purchased_at DESC
            ),
            '[]'::jsonb
        )
        INTO v_inventory
        FROM public.user_inventory ui
        LEFT JOIN public.store_items s ON s.id = ui.item_id
        WHERE ui.user_id = v_uid;

        SELECT COALESCE(jsonb_agg(to_jsonb(rm)), '[]'::jsonb)
        INTO v_matches
        FROM (
            SELECT
                m.id,
                m.status,
                m.winner_id,
                m.is_ghost_match,
                m.is_friendly,
                mp.current_score AS my_score,
                mp.finished_at,
                m.created_at
            FROM public.match_participants mp
            JOIN public.matches m ON m.id = mp.match_id
            WHERE mp.user_id = v_uid
            ORDER BY m.created_at DESC
            LIMIT 10
        ) rm;
    END IF;

    RETURN jsonb_build_object(
        'user_id', v_uid,
        'player_code', COALESCE(v_code, v_dir->>'player_code'),
        'directory', v_dir,
        'progress', v_prog,
        'leaderboard', v_lb,
        'inventory', v_inventory,
        'recent_matches', v_matches
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_player_detail(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_player_detail(UUID, TEXT) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_grant_player_compensation(
    p_user_id UUID,
    p_coins_delta INTEGER DEFAULT 0,
    p_gems_delta INTEGER DEFAULT 0,
    p_xp_delta INTEGER DEFAULT 0,
    p_reason TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_coins INTEGER := COALESCE(p_coins_delta, 0);
    v_gems INTEGER := COALESCE(p_gems_delta, 0);
    v_xp INTEGER := COALESCE(p_xp_delta, 0);
    v_reason TEXT := BTRIM(COALESCE(p_reason, ''));
    v_before RECORD;
    v_after RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'Target user_id is required for compensation';
    END IF;

    -- Approved standard safety caps: <= 10,000 coins, <= 100 gems, <= 5,000 XP
    IF v_coins < 0 OR v_coins > 10000 THEN
        RAISE EXCEPTION 'Coins compensation must be between 0 and 10,000';
    END IF;
    IF v_gems < 0 OR v_gems > 100 THEN
        RAISE EXCEPTION 'Gems compensation must be between 0 and 100';
    END IF;
    IF v_xp < 0 OR v_xp > 5000 THEN
        RAISE EXCEPTION 'XP compensation must be between 0 and 5,000';
    END IF;
    IF v_coins = 0 AND v_gems = 0 AND v_xp = 0 THEN
        RAISE EXCEPTION 'Compensation must include at least one non-zero reward';
    END IF;
    IF LENGTH(v_reason) < 3 THEN
        RAISE EXCEPTION 'A clear reason (minimum 3 characters) is required for audit logging';
    END IF;

    SELECT up.coins, up.gems, up.total_score, up.player_level
    INTO v_before
    FROM public.user_progress up
    WHERE up.user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Player user_progress record not found for user_id (%)', p_user_id;
    END IF;

    UPDATE public.user_progress up
    SET coins = COALESCE(up.coins, 100) + v_coins,
        gems = COALESCE(up.gems, 10) + v_gems,
        total_score = COALESCE(up.total_score, 0) + v_xp,
        updated_at = NOW()
    WHERE up.user_id = p_user_id
    RETURNING up.coins, up.gems, up.total_score, up.player_level INTO v_after;

    IF v_xp > 0 THEN
        UPDATE public.leaderboard lb
        SET score = GREATEST(COALESCE(lb.score, 0) + v_xp, v_after.total_score),
            updated_at = NOW()
        WHERE lb.user_id = p_user_id;
    END IF;

    PERFORM public._write_admin_audit_log(
        'grant_player_compensation',
        'player',
        p_user_id::text,
        v_reason,
        jsonb_build_object(
            'coins_delta', v_coins,
            'gems_delta', v_gems,
            'xp_delta', v_xp,
            'before', jsonb_build_object('coins', v_before.coins, 'gems', v_before.gems, 'total_score', v_before.total_score, 'player_level', v_before.player_level),
            'after', jsonb_build_object('coins', v_after.coins, 'gems', v_after.gems, 'total_score', v_after.total_score, 'player_level', v_after.player_level)
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'user_id', p_user_id,
        'coins', v_after.coins,
        'gems', v_after.gems,
        'total_score', v_after.total_score,
        'player_level', v_after.player_level
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_grant_player_compensation(UUID, INTEGER, INTEGER, INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_grant_player_compensation(UUID, INTEGER, INTEGER, INTEGER, TEXT) TO authenticated, service_role;

-- ---- Ghost Monitor, Audit Logs & Owner-Only Admins Manager ----

CREATE OR REPLACE FUNCTION public.admin_list_ghosts(
    p_limit INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_limit INTEGER := GREATEST(1, LEAST(100, COALESCE(p_limit, 30)));
    v_rows JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COALESCE(jsonb_agg(to_jsonb(sub)), '[]'::jsonb)
    INTO v_rows
    FROM (
        SELECT
            gr.id,
            gr.user_id,
            gr.display_name,
            gr.player_level,
            gr.trophies,
            gr.total_score,
            gr.use_count,
            gr.is_active,
            (gr.user_id IS NOT NULL) AS is_human,
            gr.created_at
        FROM public.ghost_recordings gr
        ORDER BY gr.is_active DESC, gr.created_at DESC
        LIMIT v_limit
    ) sub;

    RETURN v_rows;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_ghosts(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_ghosts(INTEGER) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_toggle_ghost(
    p_ghost_id UUID,
    p_is_active BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_active BOOLEAN := COALESCE(p_is_active, FALSE);
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    UPDATE public.ghost_recordings gr
    SET is_active = v_active
    WHERE gr.id = p_ghost_id;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    PERFORM public._write_admin_audit_log(
        CASE WHEN v_active THEN 'enable_ghost' ELSE 'disable_ghost' END,
        'ghost_recording',
        p_ghost_id::text,
        'تبديل حالة تسجيل شبح',
        jsonb_build_object('is_active', v_active)
    );

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_toggle_ghost(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_toggle_ghost(UUID, BOOLEAN) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_list_audit_logs(
    p_limit INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_limit INTEGER := GREATEST(1, LEAST(200, COALESCE(p_limit, 50)));
    v_rows JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COALESCE(jsonb_agg(to_jsonb(al)), '[]'::jsonb)
    INTO v_rows
    FROM (
        SELECT
            l.id,
            l.admin_email,
            l.action,
            l.target_type,
            l.target_id,
            l.reason,
            l.details,
            l.created_at
        FROM public.admin_audit_logs l
        ORDER BY l.created_at DESC
        LIMIT v_limit
    ) al;

    RETURN v_rows;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_audit_logs(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_audit_logs(INTEGER) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_list_admins()
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

    SELECT COALESCE(jsonb_agg(to_jsonb(aa) ORDER BY CASE WHEN aa.role = 'owner' THEN 0 ELSE 1 END, aa.created_at ASC), '[]'::jsonb)
    INTO v_rows
    FROM public.app_admins aa;

    RETURN jsonb_build_object(
        'is_owner', public._check_is_owner(),
        'admins', v_rows
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_admins() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_admins() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_manage_admin(
    p_action TEXT,
    p_email TEXT,
    p_role TEXT DEFAULT 'admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_act TEXT := LOWER(BTRIM(COALESCE(p_action, '')));
    v_email TEXT := LOWER(BTRIM(COALESCE(p_email, '')));
    v_role TEXT := LOWER(BTRIM(COALESCE(p_role, 'admin')));
    v_target_role TEXT;
    v_owners_count INTEGER;
BEGIN
    IF NOT public._check_is_owner() THEN
        RAISE EXCEPTION 'Forbidden: owner role required to manage admin roster';
    END IF;

    IF v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
        RAISE EXCEPTION 'Invalid email address';
    END IF;

    IF v_act = 'add' THEN
        IF v_role NOT IN ('admin', 'owner') THEN
            v_role := 'admin';
        END IF;

        INSERT INTO public.app_admins (email, role)
        VALUES (v_email, v_role)
        ON CONFLICT (email) DO UPDATE SET role = EXCLUDED.role;

        PERFORM public._write_admin_audit_log(
            'add_or_update_admin', 'app_admin', v_email, 'تحديث صلاحيات المشرفين',
            jsonb_build_object('role', v_role)
        );
    ELSIF v_act = 'remove' THEN
        SELECT LOWER(aa.role) INTO v_target_role
        FROM public.app_admins aa
        WHERE LOWER(aa.email) = v_email;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Admin email not found';
        END IF;

        IF v_target_role = 'owner' THEN
            SELECT COUNT(*) INTO v_owners_count FROM public.app_admins aa WHERE LOWER(aa.role) = 'owner';
            IF v_owners_count <= 1 THEN
                RAISE EXCEPTION 'Cannot remove the last remaining owner';
            END IF;
        END IF;

        DELETE FROM public.app_admins aa WHERE LOWER(aa.email) = v_email;

        PERFORM public._write_admin_audit_log(
            'remove_admin', 'app_admin', v_email, 'إزالة مشرف',
            jsonb_build_object('previous_role', v_target_role)
        );
    ELSE
        RAISE EXCEPTION 'Unsupported action: % (use add or remove)', v_act;
    END IF;

    RETURN public.admin_list_admins();
END;
$$;

REVOKE ALL ON FUNCTION public.admin_manage_admin(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_manage_admin(TEXT, TEXT, TEXT) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
