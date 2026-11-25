-- ============================================================================
-- AUTO-GENERATED CANONICAL SCHEMA REFERENCE — DO NOT EDIT MANUALLY!
-- Domain: 02_glory_and_knights_store.sql (منظومة المجد الـ 100، متجر الفرسان، والمقتنيات)
-- Source: supabase/migrations/001..024 (26 migrations)
-- Generator: python tools/export_supabase_schema.py
-- Summary: 2 tables | 4 RLS policies | 1 indexes | 2 triggers | 3 functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLES & COLUMN/CONSTRAINT EVOLUTION
-- ----------------------------------------------------------------------------

-- Table: public.store_items (origin: 009_glory_and_store.sql)
CREATE TABLE IF NOT EXISTS public.store_items (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN ('theme', 'frame', 'title', 'powerup')),
    price_coins INT DEFAULT 0,
    price_gems INT DEFAULT 0,
    min_level INT DEFAULT 1,
    asset_key TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
-- Effective ALTERs for public.store_items:
--   [009_glory_and_store.sql]
ALTER TABLE public.store_items ENABLE ROW LEVEL SECURITY;
--   [016_dynamic_cms_store_and_hardening.sql]
ALTER TABLE public.store_items
    ADD COLUMN IF NOT EXISTS is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 100,
    ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS cms_revision BIGINT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Table: public.user_inventory (origin: 009_glory_and_store.sql)
CREATE TABLE IF NOT EXISTS public.user_inventory (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id TEXT REFERENCES public.store_items(id) ON DELETE CASCADE,
    purchased_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, item_id)
);
-- Effective ALTERs for public.user_inventory:
--   [009_glory_and_store.sql]
ALTER TABLE public.user_inventory ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. ACTIVE RLS POLICIES
-- ----------------------------------------------------------------------------

-- Policy: "Visible or owned read store_items" ON public.store_items (latest: 016_dynamic_cms_store_and_hardening.sql)
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

-- Policy: "Owner delete user_inventory" ON public.user_inventory (latest: 009_glory_and_store.sql)
CREATE POLICY "Owner delete user_inventory"
ON public.user_inventory
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Policy: "Owner insert user_inventory" ON public.user_inventory (latest: 009_glory_and_store.sql)
CREATE POLICY "Owner insert user_inventory"
ON public.user_inventory
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Policy: "Owner read user_inventory" ON public.user_inventory (latest: 009_glory_and_store.sql)
CREATE POLICY "Owner read user_inventory"
ON public.user_inventory
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 3. ACTIVE INDEXES
-- ----------------------------------------------------------------------------

-- Index: idx_store_items_visible_sort ON public.store_items (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE INDEX IF NOT EXISTS idx_store_items_visible_sort
    ON public.store_items (is_visible, category, sort_order, min_level, id);

-- ----------------------------------------------------------------------------
-- 4. ACTIVE TRIGGERS
-- ----------------------------------------------------------------------------

-- Trigger: trg_guard_store_item_delete ON public.store_items (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE TRIGGER trg_guard_store_item_delete
BEFORE DELETE ON public.store_items
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_guard_store_item_delete();

-- Trigger: trg_store_items_cms_rev ON public.store_items (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE TRIGGER trg_store_items_cms_rev
BEFORE INSERT OR UPDATE ON public.store_items
FOR EACH ROW EXECUTE FUNCTION public.trg_fn_cms_auto_revision();

-- ----------------------------------------------------------------------------
-- 5. LATEST EFFECTIVE FUNCTIONS & RPCs
-- ----------------------------------------------------------------------------

-- Function: public.calculate_level_and_title | latest: 009_glory_and_store.sql | redefinitions: 1 | security_definer: False | search_path: False
CREATE OR REPLACE FUNCTION public.calculate_level_and_title(p_total_score INT)
RETURNS TABLE (
    out_level INT,
    out_title TEXT,
    out_cur_xp INT,
    out_next_xp INT,
    out_progress_percent FLOAT
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
#variable_conflict use_column
DECLARE
    v_lvl INT := 1;
    v_prev_xp INT := 0;
    v_target_xp INT := 250;
    v_title TEXT := 'طالب علم';
BEGIN
    WHILE COALESCE(p_total_score, 0) >= v_target_xp AND v_lvl < 100 LOOP
        v_lvl := v_lvl + 1;
        v_prev_xp := v_target_xp;
        v_target_xp := FLOOR(100.0 * POWER(v_lvl, 1.6) + 150.0 * v_lvl)::INT;
    END LOOP;

    IF v_lvl >= 90 THEN v_title := 'نخبة الأحفاد 👑';
    ELSIF v_lvl >= 80 THEN v_title := 'أسد الملاحم';
    ELSIF v_lvl >= 70 THEN v_title := 'أمير الفتح';
    ELSIF v_lvl >= 60 THEN v_title := 'وزير الديوان';
    ELSIF v_lvl >= 50 THEN v_title := 'حكيم السيرة';
    ELSIF v_lvl >= 40 THEN v_title := 'قائد الكتيبة';
    ELSIF v_lvl >= 30 THEN v_title := 'فارس المعرفة';
    ELSIF v_lvl >= 20 THEN v_title := 'محدث الميدان';
    ELSIF v_lvl >= 10 THEN v_title := 'راوي الأثر';
    ELSE v_title := 'طالب علم';
    END IF;

    RETURN QUERY SELECT
        v_lvl,
        v_title,
        GREATEST(0, COALESCE(p_total_score, 0) - v_prev_xp),
        GREATEST(1, v_target_xp - v_prev_xp),
        LEAST(1.0, GREATEST(0.0, (COALESCE(p_total_score, 0) - v_prev_xp)::FLOAT / GREATEST(1, v_target_xp - v_prev_xp)::FLOAT));
END;
$$;
-- Effective permission history for public.calculate_level_and_title:
--   [009_glory_and_store.sql] GRANT EXECUTE ON FUNCTION public.calculate_level_and_title(INT) TO anon, authenticated, service_role;

-- Function: public.purchase_store_item | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 2 | security_definer: True | search_path: True
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
-- Effective permission history for public.purchase_store_item:
--   [009_glory_and_store.sql] GRANT EXECUTE ON FUNCTION public.purchase_store_item(UUID, TEXT) TO authenticated, service_role;
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.purchase_store_item(UUID, TEXT) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.purchase_store_item(UUID, TEXT) TO authenticated, service_role;

-- Function: public.trg_fn_guard_store_item_delete | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
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
