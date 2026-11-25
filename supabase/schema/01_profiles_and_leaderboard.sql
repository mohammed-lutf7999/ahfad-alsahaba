-- ============================================================================
-- AUTO-GENERATED CANONICAL SCHEMA REFERENCE — DO NOT EDIT MANUALLY!
-- Domain: 01_profiles_and_leaderboard.sql (ملفات اللاعبين، لوحة الشرف، ودليل اللاعبين)
-- Source: supabase/migrations/001..024 (26 migrations)
-- Generator: python tools/export_supabase_schema.py
-- Summary: 3 tables | 8 RLS policies | 9 indexes | 2 triggers | 3 functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLES & COLUMN/CONSTRAINT EVOLUTION
-- ----------------------------------------------------------------------------

-- Table: public.leaderboard (origin: 001_create_leaderboard.sql)
CREATE TABLE IF NOT EXISTS public.leaderboard (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    display_name TEXT NOT NULL DEFAULT 'لاعب',
    email TEXT,
    avatar_url TEXT,
    score INTEGER NOT NULL DEFAULT 0,
    country_code TEXT DEFAULT 'XX',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
-- Effective ALTERs for public.leaderboard:
--   [001_create_leaderboard.sql]
ALTER TABLE public.leaderboard ENABLE ROW LEVEL SECURITY;
--   [008_multiplayer_rock_solid_fix.sql]
ALTER TABLE public.leaderboard ADD COLUMN IF NOT EXISTS trophies INTEGER DEFAULT 1000;
--   [008_multiplayer_rock_solid_fix.sql]
ALTER TABLE public.leaderboard ADD COLUMN IF NOT EXISTS wins_count INTEGER DEFAULT 0;
--   [008_multiplayer_rock_solid_fix.sql]
ALTER TABLE public.leaderboard ADD COLUMN IF NOT EXISTS matches_count INTEGER DEFAULT 0;
--   [009_glory_and_store.sql]
ALTER TABLE public.leaderboard
ADD COLUMN IF NOT EXISTS player_level INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS player_title TEXT DEFAULT 'طالب علم',
ADD COLUMN IF NOT EXISTS arena_id INT DEFAULT 2,
ADD COLUMN IF NOT EXISTS arena_name TEXT DEFAULT 'ميدان بدر الكبرى',
ADD COLUMN IF NOT EXISTS equipped_frame TEXT DEFAULT 'frame_wood';

-- Table: public.user_progress (origin: 002_create_user_progress.sql)
CREATE TABLE IF NOT EXISTS public.user_progress (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    display_name TEXT NOT NULL DEFAULT 'لاعب',
    avatar_index INTEGER DEFAULT 0,
    total_score INTEGER NOT NULL DEFAULT 0,
    high_score INTEGER NOT NULL DEFAULT 0,
    category_progress JSONB DEFAULT '{}'::jsonb,
    level_stars JSONB DEFAULT '{}'::jsonb,
    level_scores JSONB DEFAULT '{}'::jsonb,
    achievement_progress JSONB DEFAULT '{}'::jsonb,
    current_streak INTEGER DEFAULT 0,
    total_days_played INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
-- Effective ALTERs for public.user_progress:
--   [002_create_user_progress.sql]
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
--   [009_glory_and_store.sql]
ALTER TABLE public.user_progress
ADD COLUMN IF NOT EXISTS player_level INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS player_title TEXT DEFAULT 'طالب علم',
ADD COLUMN IF NOT EXISTS current_level_xp INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS next_level_xp INT DEFAULT 250,
ADD COLUMN IF NOT EXISTS coins INT DEFAULT 100,
ADD COLUMN IF NOT EXISTS gems INT DEFAULT 10,
ADD COLUMN IF NOT EXISTS win_streak INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS equipped_theme TEXT DEFAULT 'andalusian_gold',
ADD COLUMN IF NOT EXISTS equipped_frame TEXT DEFAULT 'frame_wood';

-- Table: public.player_directory (origin: 015_app_control_and_messages.sql)
CREATE TABLE IF NOT EXISTS public.player_directory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    player_code TEXT NOT NULL UNIQUE CHECK (player_code ~ '^SAH-[A-Z0-9]{4,8}$' AND LENGTH(player_code) BETWEEN 8 AND 12),
    display_name TEXT NOT NULL DEFAULT 'لاعب',
    email TEXT,
    trophies INTEGER NOT NULL DEFAULT 1000,
    player_level INTEGER NOT NULL DEFAULT 1,
    total_score INTEGER NOT NULL DEFAULT 0,
    platform TEXT NOT NULL DEFAULT 'android',
    app_version TEXT NOT NULL DEFAULT '1.0.17',
    version_code INTEGER NOT NULL DEFAULT 18,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.player_directory:
--   [015_app_control_and_messages.sql]
ALTER TABLE public.player_directory ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. ACTIVE RLS POLICIES
-- ----------------------------------------------------------------------------

-- Policy: "Anyone can view leaderboard" ON public.leaderboard (latest: 001_create_leaderboard.sql)
CREATE POLICY "Anyone can view leaderboard" ON public.leaderboard
    FOR SELECT USING (true);

-- Policy: "Users can delete own score" ON public.leaderboard (latest: 001_create_leaderboard.sql)
CREATE POLICY "Users can delete own score" ON public.leaderboard
    FOR DELETE USING (auth.uid() = user_id);

-- Policy: "Users can insert own score" ON public.leaderboard (latest: 001_create_leaderboard.sql)
CREATE POLICY "Users can insert own score" ON public.leaderboard
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: "Users can update own score" ON public.leaderboard (latest: 001_create_leaderboard.sql)
CREATE POLICY "Users can update own score" ON public.leaderboard
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy: "Anyone can view user progress" ON public.user_progress (latest: 006_add_seed_column.sql)
CREATE POLICY "Anyone can view user progress" ON public.user_progress FOR SELECT USING (true);

-- Policy: "Users can delete own progress" ON public.user_progress (latest: 002_create_user_progress.sql)
CREATE POLICY "Users can delete own progress" ON public.user_progress
    FOR DELETE USING (auth.uid() = user_id);

-- Policy: "Users can insert own progress" ON public.user_progress (latest: 002_create_user_progress.sql)
CREATE POLICY "Users can insert own progress" ON public.user_progress
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: "Users can update own progress" ON public.user_progress (latest: 002_create_user_progress.sql)
CREATE POLICY "Users can update own progress" ON public.user_progress
    FOR UPDATE USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 3. ACTIVE INDEXES
-- ----------------------------------------------------------------------------

-- Index: idx_leaderboard_arena_id ON public.leaderboard (origin: 009_glory_and_store.sql)
CREATE INDEX IF NOT EXISTS idx_leaderboard_arena_id ON public.leaderboard(arena_id DESC, trophies DESC);

-- Index: idx_leaderboard_player_level ON public.leaderboard (origin: 009_glory_and_store.sql)
CREATE INDEX IF NOT EXISTS idx_leaderboard_player_level ON public.leaderboard(player_level DESC);

-- Index: idx_leaderboard_score ON public.leaderboard (origin: 001_create_leaderboard.sql)
CREATE INDEX IF NOT EXISTS idx_leaderboard_score ON public.leaderboard(score DESC);

-- Index: idx_leaderboard_trophies ON public.leaderboard (origin: 008_multiplayer_rock_solid_fix.sql)
CREATE INDEX IF NOT EXISTS idx_leaderboard_trophies ON public.leaderboard(trophies DESC);

-- Index: idx_leaderboard_user_id ON public.leaderboard (origin: 001_create_leaderboard.sql)
CREATE INDEX IF NOT EXISTS idx_leaderboard_user_id ON public.leaderboard(user_id);

-- Index: idx_user_progress_user_id ON public.user_progress (origin: 002_create_user_progress.sql)
CREATE INDEX IF NOT EXISTS idx_user_progress_user_id ON public.user_progress(user_id);

-- Index: idx_player_directory_email_lower ON public.player_directory (origin: 015_app_control_and_messages.sql)
CREATE INDEX IF NOT EXISTS idx_player_directory_email_lower
    ON public.player_directory (LOWER(email))
    WHERE email IS NOT NULL;

-- Index: idx_player_directory_last_seen ON public.player_directory (origin: 015_app_control_and_messages.sql)
CREATE INDEX IF NOT EXISTS idx_player_directory_last_seen
    ON public.player_directory (last_seen_at DESC);

-- Index: idx_player_directory_name_lower ON public.player_directory (origin: 015_app_control_and_messages.sql)
CREATE INDEX IF NOT EXISTS idx_player_directory_name_lower
    ON public.player_directory (LOWER(display_name));

-- ----------------------------------------------------------------------------
-- 4. ACTIVE TRIGGERS
-- ----------------------------------------------------------------------------

-- Trigger: trg_sync_leaderboard_glory ON public.leaderboard (latest: 009_glory_and_store.sql)
CREATE TRIGGER trg_sync_leaderboard_glory
BEFORE INSERT OR UPDATE OF score, trophies, player_title ON public.leaderboard
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_sync_leaderboard_glory();

-- Trigger: trg_sync_user_progress_level ON public.user_progress (latest: 009_glory_and_store.sql)
CREATE TRIGGER trg_sync_user_progress_level
BEFORE INSERT OR UPDATE OF total_score, player_title ON public.user_progress
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_sync_user_progress_level();

-- ----------------------------------------------------------------------------
-- 5. LATEST EFFECTIVE FUNCTIONS & RPCs
-- ----------------------------------------------------------------------------

-- Function: public.sync_player_directory | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.sync_player_directory(
    p_player_code TEXT,
    p_display_name TEXT DEFAULT 'لاعب',
    p_trophies INTEGER DEFAULT 1000,
    p_player_level INTEGER DEFAULT 1,
    p_total_score INTEGER DEFAULT 0,
    p_platform TEXT DEFAULT 'android',
    p_app_version TEXT DEFAULT '1.0.17',
    p_version_code INTEGER DEFAULT 18
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_code TEXT := UPPER(BTRIM(COALESCE(p_player_code, '')));
    v_uid UUID := auth.uid();
    v_email TEXT := NULL;
    v_name TEXT := LEFT(COALESCE(NULLIF(BTRIM(p_display_name), ''), 'لاعب'), 60);
    v_platform TEXT := LEFT(COALESCE(NULLIF(LOWER(BTRIM(p_platform)), ''), 'android'), 20);
    v_app_ver TEXT := LEFT(COALESCE(NULLIF(BTRIM(p_app_version), ''), '1.0.17'), 30);
    v_trophies INTEGER := GREATEST(0, COALESCE(p_trophies, 1000));
    v_level INTEGER := GREATEST(1, LEAST(100, COALESCE(p_player_level, 1)));
    v_score INTEGER := GREATEST(0, COALESCE(p_total_score, 0));
    v_ver_code INTEGER := GREATEST(1, COALESCE(p_version_code, 18));
    v_existing_uid_row RECORD;
    v_existing_code_row RECORD;
BEGIN
    IF v_code = '' OR LENGTH(v_code) NOT BETWEEN 8 AND 12 OR v_code !~ '^SAH-[A-Z0-9]{4,8}$' THEN
        RETURN jsonb_build_object(
            'ok', FALSE,
            'error', 'Invalid player_code format (expected SAH-XXXX)'
        );
    END IF;

    IF v_uid IS NOT NULL THEN
        SELECT u.email
        INTO v_email
        FROM auth.users u
        WHERE u.id = v_uid
        LIMIT 1;

        SELECT pd.id, pd.player_code
        INTO v_existing_uid_row
        FROM public.player_directory pd
        WHERE pd.user_id = v_uid
        LIMIT 1;

        SELECT pd.id, pd.user_id
        INTO v_existing_code_row
        FROM public.player_directory pd
        WHERE pd.player_code = v_code
        LIMIT 1;

        IF v_existing_uid_row.id IS NOT NULL THEN
            -- Prevent collision if code belongs to a different authenticated user
            IF v_existing_code_row.id IS NOT NULL
               AND v_existing_code_row.id <> v_existing_uid_row.id
               AND v_existing_code_row.user_id IS NULL THEN
                DELETE FROM public.player_directory pd
                WHERE pd.id = v_existing_code_row.id
                  AND pd.user_id IS NULL;
                v_existing_code_row.id := NULL;
            END IF;

            UPDATE public.player_directory pd
            SET player_code = CASE
                    WHEN v_existing_code_row.id IS NULL OR v_existing_code_row.id = v_existing_uid_row.id THEN v_code
                    ELSE pd.player_code
                END,
                display_name = v_name,
                email = COALESCE(v_email, pd.email),
                trophies = v_trophies,
                player_level = v_level,
                total_score = v_score,
                platform = v_platform,
                app_version = v_app_ver,
                version_code = v_ver_code,
                last_seen_at = NOW(),
                updated_at = NOW()
            WHERE pd.id = v_existing_uid_row.id
            RETURNING pd.player_code INTO v_code;
        ELSIF v_existing_code_row.id IS NOT NULL AND v_existing_code_row.user_id IS NULL THEN
            -- Claim previously-guest device record on first Google sign-in
            UPDATE public.player_directory pd
            SET user_id = v_uid,
                display_name = v_name,
                email = v_email,
                trophies = v_trophies,
                player_level = v_level,
                total_score = v_score,
                platform = v_platform,
                app_version = v_app_ver,
                version_code = v_ver_code,
                last_seen_at = NOW(),
                updated_at = NOW()
            WHERE pd.id = v_existing_code_row.id;
        ELSIF v_existing_code_row.id IS NOT NULL AND v_existing_code_row.user_id <> v_uid THEN
            RETURN jsonb_build_object(
                'ok', FALSE,
                'error', 'Player code already claimed by another account'
            );
        ELSE
            INSERT INTO public.player_directory (
                user_id, player_code, display_name, email, trophies, player_level,
                total_score, platform, app_version, version_code, last_seen_at, updated_at
            )
            VALUES (
                v_uid, v_code, v_name, v_email, v_trophies, v_level,
                v_score, v_platform, v_app_ver, v_ver_code, NOW(), NOW()
            );
        END IF;
    ELSE
        -- Guest user flow: never overwrite a row already bound to an authenticated user
        SELECT pd.id, pd.user_id
        INTO v_existing_code_row
        FROM public.player_directory pd
        WHERE pd.player_code = v_code
        LIMIT 1;

        IF v_existing_code_row.id IS NOT NULL THEN
            IF v_existing_code_row.user_id IS NOT NULL THEN
                RETURN jsonb_build_object(
                    'ok', FALSE,
                    'error', 'Player code belongs to an authenticated account'
                );
            END IF;

            UPDATE public.player_directory pd
            SET display_name = v_name,
                trophies = v_trophies,
                player_level = v_level,
                total_score = v_score,
                platform = v_platform,
                app_version = v_app_ver,
                version_code = v_ver_code,
                last_seen_at = NOW(),
                updated_at = NOW()
            WHERE pd.id = v_existing_code_row.id;
        ELSE
            INSERT INTO public.player_directory (
                user_id, player_code, display_name, trophies, player_level,
                total_score, platform, app_version, version_code, last_seen_at, updated_at
            )
            VALUES (
                NULL, v_code, v_name, v_trophies, v_level,
                v_score, v_platform, v_app_ver, v_ver_code, NOW(), NOW()
            );
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'ok', TRUE,
        'player_code', v_code,
        'is_authenticated', (v_uid IS NOT NULL)
    );
END;
$$;
-- Effective permission history for public.sync_player_directory:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.sync_player_directory(TEXT, TEXT, INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.sync_player_directory(TEXT, TEXT, INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER) TO anon, authenticated, service_role;

-- Function: public.trg_fn_sync_leaderboard_glory | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 2 | security_definer: True | search_path: True
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

-- Function: public.trg_fn_sync_user_progress_level | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 2 | security_definer: True | search_path: True
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
