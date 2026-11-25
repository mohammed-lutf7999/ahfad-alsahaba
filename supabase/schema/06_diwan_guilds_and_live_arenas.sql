-- ============================================================================
-- AUTO-GENERATED CANONICAL SCHEMA REFERENCE — DO NOT EDIT MANUALLY!
-- Domain: 06_diwan_guilds_and_live_arenas.sql (ديوان الأحفاد، فلتر الأخلاق، الكتائب، والبطولات الجماعية الحية)
-- Source: supabase/migrations/001..024 (26 migrations)
-- Generator: python tools/export_supabase_schema.py
-- Summary: 5 tables | 5 RLS policies | 6 indexes | 0 triggers | 13 functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLES & COLUMN/CONSTRAINT EVOLUTION
-- ----------------------------------------------------------------------------

-- Table: public.chat_messages (origin: 018_diwan_live_chat.sql)
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    player_code TEXT,
    display_name TEXT NOT NULL CHECK (char_length(BTRIM(display_name)) BETWEEN 1 AND 50),
    avatar_index INTEGER NOT NULL DEFAULT 0,
    user_rank TEXT NOT NULL DEFAULT 'فارس',
    content TEXT NOT NULL CHECK (char_length(BTRIM(content)) BETWEEN 1 AND 250),
    channel TEXT NOT NULL DEFAULT 'global',
    message_kind TEXT NOT NULL DEFAULT 'text' CHECK (message_kind IN ('text', 'challenge_invite')),
    invite_room_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.chat_messages:
--   [018_diwan_live_chat.sql]
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Table: public.guild_members (origin: 019_guilds_and_live_arenas.sql)
CREATE TABLE IF NOT EXISTS public.guild_members (
    guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT 'فارس',
    avatar_index INTEGER NOT NULL DEFAULT 0,
    role TEXT NOT NULL DEFAULT 'عضو' CHECK (role IN ('قائد', 'نائب', 'عضو')),
    weekly_contribution INTEGER NOT NULL DEFAULT 0,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.guild_members:
--   [019_guilds_and_live_arenas.sql]
ALTER TABLE public.guild_members ENABLE ROW LEVEL SECURITY;

-- Table: public.guilds (origin: 019_guilds_and_live_arenas.sql)
CREATE TABLE IF NOT EXISTS public.guilds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL CHECK (char_length(BTRIM(name)) BETWEEN 3 AND 30),
    description TEXT NOT NULL DEFAULT '',
    banner_icon INTEGER NOT NULL DEFAULT 0,
    weekly_score BIGINT NOT NULL DEFAULT 0,
    total_score BIGINT NOT NULL DEFAULT 0,
    max_members INTEGER NOT NULL DEFAULT 30 CHECK (max_members BETWEEN 5 AND 30),
    leader_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.guilds:
--   [019_guilds_and_live_arenas.sql]
ALTER TABLE public.guilds ENABLE ROW LEVEL SECURITY;

-- Table: public.live_quiz_participants (origin: 019_guilds_and_live_arenas.sql)
CREATE TABLE IF NOT EXISTS public.live_quiz_participants (
    session_id UUID NOT NULL REFERENCES public.live_quiz_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT 'متسابق',
    avatar_index INTEGER NOT NULL DEFAULT 0,
    score INTEGER NOT NULL DEFAULT 0,
    correct_count INTEGER NOT NULL DEFAULT 0,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (session_id, user_id)
);
-- Effective ALTERs for public.live_quiz_participants:
--   [019_guilds_and_live_arenas.sql]
ALTER TABLE public.live_quiz_participants ENABLE ROW LEVEL SECURITY;

-- Table: public.live_quiz_sessions (origin: 019_guilds_and_live_arenas.sql)
CREATE TABLE IF NOT EXISTS public.live_quiz_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pin_code VARCHAR(6) UNIQUE NOT NULL,
    title TEXT NOT NULL DEFAULT 'بطولة الفرسان الحية',
    category_id TEXT NOT NULL DEFAULT 'quran',
    host_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'active', 'finished')),
    current_question_index INTEGER NOT NULL DEFAULT 0,
    question_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    participants_count INTEGER NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '6 hours'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.live_quiz_sessions:
--   [019_guilds_and_live_arenas.sql]
ALTER TABLE public.live_quiz_sessions ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. ACTIVE RLS POLICIES
-- ----------------------------------------------------------------------------

-- Policy: "Read diwan messages last 24h" ON public.chat_messages (latest: 018_diwan_live_chat.sql)
CREATE POLICY "Read diwan messages last 24h"
    ON public.chat_messages FOR SELECT
    TO anon, authenticated
    USING (created_at >= NOW() - INTERVAL '24 hours');

-- Policy: "Public view guild members" ON public.guild_members (latest: 019_guilds_and_live_arenas.sql)
CREATE POLICY "Public view guild members"
    ON public.guild_members FOR SELECT
    TO anon, authenticated
    USING (TRUE);

-- Policy: "Public view guilds" ON public.guilds (latest: 019_guilds_and_live_arenas.sql)
CREATE POLICY "Public view guilds"
    ON public.guilds FOR SELECT
    TO anon, authenticated
    USING (TRUE);

-- Policy: "Authenticated view live participants" ON public.live_quiz_participants (latest: 019_guilds_and_live_arenas.sql)
CREATE POLICY "Authenticated view live participants"
    ON public.live_quiz_participants FOR SELECT
    TO authenticated
    USING (TRUE);

-- Policy: "Authenticated view live sessions" ON public.live_quiz_sessions (latest: 019_guilds_and_live_arenas.sql)
CREATE POLICY "Authenticated view live sessions"
    ON public.live_quiz_sessions FOR SELECT
    TO authenticated
    USING (TRUE);

-- ----------------------------------------------------------------------------
-- 3. ACTIVE INDEXES
-- ----------------------------------------------------------------------------

-- Index: idx_chat_channel_created ON public.chat_messages (origin: 018_diwan_live_chat.sql)
CREATE INDEX IF NOT EXISTS idx_chat_channel_created
    ON public.chat_messages (channel, created_at DESC);

-- Index: idx_chat_user_created ON public.chat_messages (origin: 018_diwan_live_chat.sql)
CREATE INDEX IF NOT EXISTS idx_chat_user_created
    ON public.chat_messages (user_id, created_at DESC);

-- Index: idx_guild_members_guild_id ON public.guild_members (origin: 019_guilds_and_live_arenas.sql)
CREATE INDEX IF NOT EXISTS idx_guild_members_guild_id
    ON public.guild_members (guild_id, weekly_contribution DESC);

-- Index: idx_guilds_weekly_score ON public.guilds (origin: 019_guilds_and_live_arenas.sql)
CREATE INDEX IF NOT EXISTS idx_guilds_weekly_score
    ON public.guilds (weekly_score DESC, total_score DESC);

-- Index: idx_live_participants_score ON public.live_quiz_participants (origin: 019_guilds_and_live_arenas.sql)
CREATE INDEX IF NOT EXISTS idx_live_participants_score
    ON public.live_quiz_participants (session_id, score DESC);

-- Index: idx_live_sessions_pin ON public.live_quiz_sessions (origin: 019_guilds_and_live_arenas.sql)
CREATE INDEX IF NOT EXISTS idx_live_sessions_pin
    ON public.live_quiz_sessions (pin_code);

-- ----------------------------------------------------------------------------
-- 5. LATEST EFFECTIVE FUNCTIONS & RPCs
-- ----------------------------------------------------------------------------

-- Function: public._diwan_contains_profanity | latest: 022_hotfix_diwan_profanity_filter.sql | redefinitions: 2 | security_definer: False | search_path: True
CREATE OR REPLACE FUNCTION public._diwan_contains_profanity(p_text TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_raw TEXT := LOWER(BTRIM(COALESCE(p_text, '')));
    v_clean TEXT;
    v_compact TEXT;
    v_compact_dedup TEXT;
    v_words TEXT[];
    v_tok TEXT;
    v_tok_dedup TEXT;
    v_w TEXT;
    v_w_dedup TEXT;
    -- Short roots (2-3 letters): matched ONLY as standalone words to prevent
    -- false positives on innocent words like «اكسب», «مكسرات», «تكسير».
    v_short_exact_words TEXT[] := ARRAY[
        'كس', 'طيز', 'زبي', 'كلب', 'الكلب', 'غبي'
    ];
    -- Explicit long roots (>= 4 letters, normalized with أ/إ/آ->ا and ة->ه):
    -- matched across normalized & compacted text to catch separator/stretch evasion.
    v_long_roots TEXT[] := ARRAY[
        'حمار', 'تافه', 'حقير', 'لعنه', 'يلعن', 'شرموط', 'قحبه',
        'ابنالكلب', 'منيك', 'خنزير', 'سافل', 'منحط',
        'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'slut', 'whore', 'dick', 'pussy'
    ];
BEGIN
    IF v_raw = '' THEN
        RETURN FALSE;
    END IF;

    -- 1. Block external spam/phishing links
    IF v_raw ~ '(https?://|www\.|t\.me/|discord\.gg)' THEN
        RETURN TRUE;
    END IF;

    -- 2. Normalize Arabic Unicode properly using PostgreSQL E'' escape syntax:
    --    strip tatweel (\u0640), tashkeel (\u064B-\u065F), superscript alef (\u0670),
    --    and fold alef/alef-maksura/ta-marbuta forms.
    v_clean := regexp_replace(v_raw, E'[\u0640\u064B-\u065F\u0670]', '', 'g');
    v_clean := translate(v_clean, 'أإآىة', 'ااايه');

    -- 3. Standalone token match for short roots (prevents substring false positives)
    v_words := regexp_split_to_array(v_clean, E'[^a-z0-9\u0621-\u064A]+');
    FOREACH v_tok IN ARRAY v_words LOOP
        IF v_tok IS NULL OR v_tok = '' THEN
            CONTINUE;
        END IF;
        v_tok_dedup := regexp_replace(v_tok, '(.)\1+', '\1', 'g');
        IF v_tok = ANY(v_short_exact_words) OR v_tok_dedup = ANY(v_short_exact_words) THEN
            RETURN TRUE;
        END IF;
    END LOOP;

    -- 4. Substring & anti-evasion match for explicit long roots (>= 4 chars)
    v_compact := regexp_replace(v_clean, E'[\\s._*|\\-/]+', '', 'g');
    v_compact_dedup := regexp_replace(v_compact, '(.)\1+', '\1', 'g');

    FOREACH v_w IN ARRAY v_long_roots LOOP
        v_w_dedup := regexp_replace(v_w, '(.)\1+', '\1', 'g');
        IF position(v_w IN v_clean) > 0
           OR position(v_w IN v_compact) > 0
           OR position(v_w_dedup IN v_compact_dedup) > 0 THEN
            RETURN TRUE;
        END IF;
    END LOOP;

    RETURN FALSE;
END;
$$;
-- Effective permission history for public._diwan_contains_profanity:
--   [022_hotfix_diwan_profanity_filter.sql] REVOKE ALL ON FUNCTION public._diwan_contains_profanity(TEXT) FROM PUBLIC, anon, authenticated;
--   [022_hotfix_diwan_profanity_filter.sql] GRANT EXECUTE ON FUNCTION public._diwan_contains_profanity(TEXT) TO service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public._diwan_contains_profanity FROM PUBLIC, anon; -- via DO block

-- Function: public.contribute_guild_score | latest: 019_guilds_and_live_arenas.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.contribute_guild_score(
    p_points INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_pts INTEGER := LEAST(GREATEST(COALESCE(p_points, 0), 0), 500);
    v_guild_id UUID;
BEGIN
    IF v_uid IS NULL OR v_pts = 0 THEN
        RETURN jsonb_build_object('ok', TRUE, 'added', 0);
    END IF;

    UPDATE public.guild_members gm
    SET weekly_contribution = gm.weekly_contribution + v_pts
    WHERE gm.user_id = v_uid
    RETURNING gm.guild_id INTO v_guild_id;

    IF v_guild_id IS NOT NULL THEN
        UPDATE public.guilds g
        SET weekly_score = g.weekly_score + v_pts,
            total_score = g.total_score + v_pts
        WHERE g.id = v_guild_id;
    END IF;

    RETURN jsonb_build_object('ok', TRUE, 'guild_id', v_guild_id, 'added', v_pts);
END;
$$;
-- Effective permission history for public.contribute_guild_score:
--   [019_guilds_and_live_arenas.sql] REVOKE ALL ON FUNCTION public.contribute_guild_score(INTEGER) FROM PUBLIC;
--   [019_guilds_and_live_arenas.sql] GRANT EXECUTE ON FUNCTION public.contribute_guild_score(INTEGER) TO authenticated, service_role;

-- Function: public.create_guild | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 2 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.create_guild(
    p_name TEXT,
    p_description TEXT DEFAULT '',
    p_banner_icon INTEGER DEFAULT 0,
    p_leader_name TEXT DEFAULT 'قائد الكتيبة',
    p_avatar_index INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_name TEXT := BTRIM(COALESCE(p_name, ''));
    v_desc TEXT := LEFT(BTRIM(COALESCE(p_description, '')), 120);
    v_icon INTEGER := LEAST(GREATEST(COALESCE(p_banner_icon, 0), 0), 12);
    v_leader_name TEXT := LEFT(COALESCE(NULLIF(BTRIM(p_leader_name), ''), 'قائد الكتيبة'), 40);
    v_avatar INTEGER := GREATEST(COALESCE(p_avatar_index, 0), 0);
    v_guild public.guilds%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'يلزم تسجيل الدخول بحساب Google لتأسيس كتيبة';
    END IF;

    PERFORM public._assert_player_allowed(v_uid, 'guilds');

    IF char_length(v_name) < 3 OR char_length(v_name) > 30 THEN
        RAISE EXCEPTION 'يجب أن يكون اسم الكتيبة بين 3 و 30 حرفاً';
    END IF;

    IF public._diwan_contains_profanity(v_name) OR public._diwan_contains_profanity(v_desc) THEN
        RAISE EXCEPTION 'يرجى اختيار اسم ووصف لائقين للكتيبة';
    END IF;

    IF EXISTS (SELECT 1 FROM public.guild_members gm WHERE gm.user_id = v_uid) THEN
        RAISE EXCEPTION 'أنت منضم بالفعل لكتيبة أخرى؛ غادرها أولاً لتأسيس راية جديدة';
    END IF;

    INSERT INTO public.guilds (name, description, banner_icon, leader_id)
    VALUES (v_name, v_desc, v_icon, v_uid)
    RETURNING * INTO v_guild;

    INSERT INTO public.guild_members (guild_id, user_id, display_name, avatar_index, role)
    VALUES (v_guild.id, v_uid, v_leader_name, v_avatar, 'قائد');

    RETURN to_jsonb(v_guild);
END;
$$;
-- Effective permission history for public.create_guild:
--   [019_guilds_and_live_arenas.sql] REVOKE ALL ON FUNCTION public.create_guild(TEXT, TEXT, INTEGER, TEXT, INTEGER) FROM PUBLIC;
--   [019_guilds_and_live_arenas.sql] GRANT EXECUTE ON FUNCTION public.create_guild(TEXT, TEXT, INTEGER, TEXT, INTEGER) TO authenticated, service_role;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.create_guild(TEXT, TEXT, INTEGER, TEXT, INTEGER) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.create_guild(TEXT, TEXT, INTEGER, TEXT, INTEGER) TO authenticated, service_role;

-- Function: public.create_live_quiz_session | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 2 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.create_live_quiz_session(
    p_title TEXT,
    p_category_id TEXT DEFAULT 'quran',
    p_question_ids JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_title TEXT := LEFT(COALESCE(NULLIF(BTRIM(p_title), ''), 'بطولة الفرسان الحية'), 60);
    v_cat TEXT := COALESCE(NULLIF(BTRIM(p_category_id), ''), 'quran');
    v_pin TEXT;
    v_attempts INTEGER := 0;
    v_session public.live_quiz_sessions%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'يلزم تسجيل الدخول بحساب Google لإنشاء بطولة حية';
    END IF;

    PERFORM public._assert_player_allowed(v_uid, 'host_live_arena');

    LOOP
        v_attempts := v_attempts + 1;
        v_pin := LPAD((FLOOR(RANDOM() * 90000) + 10000)::integer::text, 5, '0');
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.live_quiz_sessions s WHERE s.pin_code = v_pin
        ) OR v_attempts >= 15;
    END LOOP;

    INSERT INTO public.live_quiz_sessions (
        pin_code, title, category_id, host_id, question_ids, status
    )
    VALUES (
        v_pin,
        v_title,
        v_cat,
        v_uid,
        COALESCE(p_question_ids, '[]'::jsonb),
        'waiting'
    )
    RETURNING * INTO v_session;

    RETURN to_jsonb(v_session);
END;
$$;
-- Effective permission history for public.create_live_quiz_session:
--   [019_guilds_and_live_arenas.sql] REVOKE ALL ON FUNCTION public.create_live_quiz_session(TEXT, TEXT, JSONB) FROM PUBLIC;
--   [019_guilds_and_live_arenas.sql] GRANT EXECUTE ON FUNCTION public.create_live_quiz_session(TEXT, TEXT, JSONB) TO authenticated, service_role;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.create_live_quiz_session(TEXT, TEXT, JSONB) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.create_live_quiz_session(TEXT, TEXT, JSONB) TO authenticated, service_role;

-- Function: public.get_diwan_messages | latest: 018_diwan_live_chat.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.get_diwan_messages(
    p_channel TEXT DEFAULT 'global',
    p_limit INTEGER DEFAULT 40
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_channel TEXT := LOWER(BTRIM(COALESCE(p_channel, 'global')));
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 40), 1), 80);
    v_rows JSONB := '[]'::jsonb;
BEGIN
    IF v_channel = '' THEN
        v_channel := 'global';
    END IF;

    SELECT COALESCE(
        jsonb_agg(to_jsonb(t) ORDER BY t.created_at ASC),
        '[]'::jsonb
    )
    INTO v_rows
    FROM (
        SELECT
            cm.id,
            cm.user_id,
            cm.player_code,
            cm.display_name,
            cm.avatar_index,
            cm.user_rank,
            cm.content,
            cm.channel,
            cm.message_kind,
            cm.invite_room_code,
            cm.created_at
        FROM public.chat_messages cm
        WHERE cm.channel = v_channel
          AND cm.created_at >= NOW() - INTERVAL '24 hours'
        ORDER BY cm.created_at DESC
        LIMIT v_limit
    ) t;

    RETURN v_rows;
END;
$$;
-- Effective permission history for public.get_diwan_messages:
--   [018_diwan_live_chat.sql] REVOKE ALL ON FUNCTION public.get_diwan_messages(TEXT, INTEGER) FROM PUBLIC;
--   [018_diwan_live_chat.sql] GRANT EXECUTE ON FUNCTION public.get_diwan_messages(TEXT, INTEGER) TO anon, authenticated, service_role;

-- Function: public.get_guilds_overview | latest: 019_guilds_and_live_arenas.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.get_guilds_overview(
    p_limit INTEGER DEFAULT 25
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
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 25), 1), 50);
    v_my_guild_id UUID := NULL;
    v_my_guild JSONB := NULL;
    v_my_members JSONB := '[]'::jsonb;
    v_leaderboard JSONB := '[]'::jsonb;
BEGIN
    IF v_uid IS NOT NULL THEN
        SELECT gm.guild_id INTO v_my_guild_id
        FROM public.guild_members gm
        WHERE gm.user_id = v_uid
        LIMIT 1;
    END IF;

    IF v_my_guild_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'id', g.id,
            'name', g.name,
            'description', g.description,
            'banner_icon', g.banner_icon,
            'weekly_score', g.weekly_score,
            'total_score', g.total_score,
            'max_members', g.max_members,
            'leader_id', g.leader_id,
            'created_at', g.created_at,
            'members_count', (SELECT COUNT(*) FROM public.guild_members gm2 WHERE gm2.guild_id = g.id)
        )
        INTO v_my_guild
        FROM public.guilds g
        WHERE g.id = v_my_guild_id;

        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'guild_id', gm.guild_id,
                    'user_id', gm.user_id,
                    'display_name', gm.display_name,
                    'avatar_index', gm.avatar_index,
                    'role', gm.role,
                    'weekly_contribution', gm.weekly_contribution,
                    'joined_at', gm.joined_at
                )
                ORDER BY gm.weekly_contribution DESC, gm.joined_at ASC
            ),
            '[]'::jsonb
        )
        INTO v_my_members
        FROM public.guild_members gm
        WHERE gm.guild_id = v_my_guild_id;
    END IF;

    SELECT COALESCE(
        jsonb_agg(to_jsonb(t) ORDER BY t.weekly_score DESC, t.total_score DESC),
        '[]'::jsonb
    )
    INTO v_leaderboard
    FROM (
        SELECT
            g.id,
            g.name,
            g.description,
            g.banner_icon,
            g.weekly_score,
            g.total_score,
            g.max_members,
            g.leader_id,
            g.created_at,
            COUNT(gm.user_id)::integer AS members_count
        FROM public.guilds g
        LEFT JOIN public.guild_members gm ON gm.guild_id = g.id
        GROUP BY g.id
        ORDER BY g.weekly_score DESC, g.total_score DESC
        LIMIT v_limit
    ) t;

    RETURN jsonb_build_object(
        'my_guild', v_my_guild,
        'my_members', v_my_members,
        'leaderboard', v_leaderboard
    );
END;
$$;
-- Effective permission history for public.get_guilds_overview:
--   [019_guilds_and_live_arenas.sql] REVOKE ALL ON FUNCTION public.get_guilds_overview(INTEGER) FROM PUBLIC;
--   [019_guilds_and_live_arenas.sql] GRANT EXECUTE ON FUNCTION public.get_guilds_overview(INTEGER) TO anon, authenticated, service_role;

-- Function: public.join_guild | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 2 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.join_guild(
    p_guild_id UUID,
    p_display_name TEXT DEFAULT 'فارس',
    p_avatar_index INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_name TEXT := LEFT(COALESCE(NULLIF(BTRIM(p_display_name), ''), 'فارس'), 40);
    v_avatar INTEGER := GREATEST(COALESCE(p_avatar_index, 0), 0);
    v_guild public.guilds%ROWTYPE;
    v_count INTEGER := 0;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'يلزم تسجيل الدخول بحساب Google للانضمام لكتيبة';
    END IF;

    PERFORM public._assert_player_allowed(v_uid, 'guilds');

    IF EXISTS (SELECT 1 FROM public.guild_members gm WHERE gm.user_id = v_uid) THEN
        RAISE EXCEPTION 'أنت عضو في كتيبة حالياً؛ غادرها أولاً قبل الانضمام لغيرها';
    END IF;

    SELECT * INTO v_guild
    FROM public.guilds g
    WHERE g.id = p_guild_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'الكتيبة غير موجودة';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM public.guild_members gm
    WHERE gm.guild_id = p_guild_id;

    IF v_count >= v_guild.max_members THEN
        RAISE EXCEPTION 'اكتمل عدد أعضاء الكتيبة (% أعضاء)', v_guild.max_members;
    END IF;

    INSERT INTO public.guild_members (guild_id, user_id, display_name, avatar_index, role)
    VALUES (p_guild_id, v_uid, v_name, v_avatar, 'عضو');

    RETURN jsonb_build_object('ok', TRUE, 'guild_id', p_guild_id, 'members_count', v_count + 1);
END;
$$;
-- Effective permission history for public.join_guild:
--   [019_guilds_and_live_arenas.sql] REVOKE ALL ON FUNCTION public.join_guild(UUID, TEXT, INTEGER) FROM PUBLIC;
--   [019_guilds_and_live_arenas.sql] GRANT EXECUTE ON FUNCTION public.join_guild(UUID, TEXT, INTEGER) TO authenticated, service_role;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.join_guild(UUID, TEXT, INTEGER) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.join_guild(UUID, TEXT, INTEGER) TO authenticated, service_role;

-- Function: public.join_live_quiz_session | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 2 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.join_live_quiz_session(
    p_pin_code TEXT,
    p_display_name TEXT DEFAULT 'متسابق',
    p_avatar_index INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_pin TEXT := UPPER(BTRIM(COALESCE(p_pin_code, '')));
    v_name TEXT := LEFT(COALESCE(NULLIF(BTRIM(p_display_name), ''), 'متسابق'), 40);
    v_avatar INTEGER := GREATEST(COALESCE(p_avatar_index, 0), 0);
    v_session public.live_quiz_sessions%ROWTYPE;
    v_count INTEGER := 0;
    v_participants JSONB := '[]'::jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'يلزم تسجيل الدخول بحساب Google للمشاركة في البطولة الحية';
    END IF;

    PERFORM public._assert_player_allowed(v_uid, 'live_arena_join');

    SELECT * INTO v_session
    FROM public.live_quiz_sessions s
    WHERE s.pin_code = v_pin
      AND s.status IN ('waiting', 'active')
      AND s.expires_at > NOW()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'لم يتم العثور على بطولة نشطة بهذا الرمز';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM public.live_quiz_participants p
    WHERE p.session_id = v_session.id;

    IF v_count >= 100 AND NOT EXISTS (
        SELECT 1 FROM public.live_quiz_participants p
        WHERE p.session_id = v_session.id AND p.user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'اكتمل الحد الأقصى للبطولة (100 مشارك)';
    END IF;

    INSERT INTO public.live_quiz_participants (session_id, user_id, display_name, avatar_index)
    VALUES (v_session.id, v_uid, v_name, v_avatar)
    ON CONFLICT (session_id, user_id) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        avatar_index = EXCLUDED.avatar_index;

    SELECT COUNT(*) INTO v_count
    FROM public.live_quiz_participants p
    WHERE p.session_id = v_session.id;

    UPDATE public.live_quiz_sessions s
    SET participants_count = v_count
    WHERE s.id = v_session.id
    RETURNING * INTO v_session;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'session_id', p.session_id,
                'user_id', p.user_id,
                'display_name', p.display_name,
                'avatar_index', p.avatar_index,
                'score', p.score,
                'correct_count', p.correct_count
            )
            ORDER BY p.score DESC, p.joined_at ASC
        ),
        '[]'::jsonb
    )
    INTO v_participants
    FROM public.live_quiz_participants p
    WHERE p.session_id = v_session.id;

    RETURN jsonb_build_object(
        'session', to_jsonb(v_session),
        'participants', v_participants
    );
END;
$$;
-- Effective permission history for public.join_live_quiz_session:
--   [019_guilds_and_live_arenas.sql] REVOKE ALL ON FUNCTION public.join_live_quiz_session(TEXT, TEXT, INTEGER) FROM PUBLIC;
--   [019_guilds_and_live_arenas.sql] GRANT EXECUTE ON FUNCTION public.join_live_quiz_session(TEXT, TEXT, INTEGER) TO authenticated, service_role;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.join_live_quiz_session(TEXT, TEXT, INTEGER) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.join_live_quiz_session(TEXT, TEXT, INTEGER) TO authenticated, service_role;

-- Function: public.leave_guild | latest: 019_guilds_and_live_arenas.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.leave_guild()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_member public.guild_members%ROWTYPE;
    v_next_leader UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'يلزم تسجيل الدخول';
    END IF;

    SELECT * INTO v_member
    FROM public.guild_members gm
    WHERE gm.user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', TRUE, 'left', FALSE);
    END IF;

    DELETE FROM public.guild_members gm WHERE gm.user_id = v_uid;

    IF v_member.role = 'قائد' THEN
        SELECT gm.user_id INTO v_next_leader
        FROM public.guild_members gm
        WHERE gm.guild_id = v_member.guild_id
        ORDER BY gm.weekly_contribution DESC, gm.joined_at ASC
        LIMIT 1;

        IF v_next_leader IS NOT NULL THEN
            UPDATE public.guild_members gm
            SET role = 'قائد'
            WHERE gm.user_id = v_next_leader;

            UPDATE public.guilds g
            SET leader_id = v_next_leader
            WHERE g.id = v_member.guild_id;
        ELSE
            DELETE FROM public.guilds g WHERE g.id = v_member.guild_id;
        END IF;
    END IF;

    RETURN jsonb_build_object('ok', TRUE, 'left', TRUE, 'guild_id', v_member.guild_id);
END;
$$;
-- Effective permission history for public.leave_guild:
--   [019_guilds_and_live_arenas.sql] REVOKE ALL ON FUNCTION public.leave_guild() FROM PUBLIC;
--   [019_guilds_and_live_arenas.sql] GRANT EXECUTE ON FUNCTION public.leave_guild() TO authenticated, service_role;

-- Function: public.report_diwan_message | latest: 018_diwan_live_chat.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.report_diwan_message(
    p_message_id UUID,
    p_reason TEXT DEFAULT 'مخالفة آداب الديوان'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_reason TEXT := COALESCE(NULLIF(BTRIM(p_reason), ''), 'مخالفة آداب الديوان');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'يلزم تسجيل الدخول للإبلاغ';
    END IF;

    INSERT INTO public.diwan_reports (message_id, reporter_id, reason)
    VALUES (p_message_id, v_uid, LEFT(v_reason, 120))
    ON CONFLICT (message_id, reporter_id) DO NOTHING;

    RETURN jsonb_build_object('ok', TRUE, 'message_id', p_message_id);
END;
$$;
-- Effective permission history for public.report_diwan_message:
--   [018_diwan_live_chat.sql] REVOKE ALL ON FUNCTION public.report_diwan_message(UUID, TEXT) FROM PUBLIC;
--   [018_diwan_live_chat.sql] GRANT EXECUTE ON FUNCTION public.report_diwan_message(UUID, TEXT) TO authenticated, service_role;

-- Function: public.send_diwan_message | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 2 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.send_diwan_message(
    p_content TEXT,
    p_channel TEXT DEFAULT 'global',
    p_display_name TEXT DEFAULT 'فارس',
    p_avatar_index INTEGER DEFAULT 0,
    p_user_rank TEXT DEFAULT 'فارس',
    p_player_code TEXT DEFAULT NULL,
    p_message_kind TEXT DEFAULT 'text',
    p_invite_room_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_channel TEXT := LOWER(BTRIM(COALESCE(p_channel, 'global')));
    v_content TEXT := BTRIM(COALESCE(p_content, ''));
    v_display_name TEXT := BTRIM(COALESCE(p_display_name, 'فارس'));
    v_avatar INTEGER := GREATEST(COALESCE(p_avatar_index, 0), 0);
    v_rank TEXT := COALESCE(NULLIF(BTRIM(p_user_rank), ''), 'فارس');
    v_code TEXT := NULLIF(UPPER(BTRIM(COALESCE(p_player_code, ''))), '');
    v_kind TEXT := CASE WHEN p_message_kind = 'challenge_invite' THEN 'challenge_invite' ELSE 'text' END;
    v_room_code TEXT := NULLIF(BTRIM(COALESCE(p_invite_room_code, '')), '');
    v_last_sent TIMESTAMPTZ;
    v_inserted public.chat_messages%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'يلزم تسجيل الدخول بحساب Google للمشاركة في الديوان';
    END IF;

    PERFORM public._assert_player_allowed(v_uid, 'diwan');

    IF v_channel = '' THEN
        v_channel := 'global';
    END IF;
    IF v_display_name = '' THEN
        v_display_name := 'فارس';
    END IF;
    v_display_name := LEFT(v_display_name, 50);

    IF char_length(v_content) < 1 OR char_length(v_content) > 250 THEN
        RAISE EXCEPTION 'يجب أن يكون نص الرسالة بين 1 و 250 حرفاً';
    END IF;

    IF public._diwan_contains_profanity(v_content) OR public._diwan_contains_profanity(v_display_name) THEN
        RAISE EXCEPTION 'يرجى الالتزام بالآداب الإسلامية والابتعاد عن الألفاظ أو الروابط المخالفة';
    END IF;

    IF v_kind = 'challenge_invite' AND (v_room_code IS NULL OR v_room_code !~ '^[0-9]{6}$') THEN
        RAISE EXCEPTION 'رمز غرفة التحدي غير صالح';
    END IF;

    IF v_code IS NOT NULL AND v_code !~ '^SAH-[A-Z0-9]{4,8}$' THEN
        v_code := NULL;
    END IF;

    SELECT MAX(cm.created_at)
    INTO v_last_sent
    FROM public.chat_messages cm
    WHERE cm.user_id = v_uid
      AND cm.created_at > NOW() - INTERVAL '3 seconds';

    IF v_last_sent IS NOT NULL THEN
        RAISE EXCEPTION 'انتظر 3 ثوانٍ قبل إرسال رسالة جديدة';
    END IF;

    DELETE FROM public.chat_messages cm
    WHERE cm.id IN (
        SELECT old_cm.id
        FROM public.chat_messages old_cm
        WHERE old_cm.created_at < NOW() - INTERVAL '24 hours'
        LIMIT 25
    );

    INSERT INTO public.chat_messages (
        user_id, player_code, display_name, avatar_index,
        user_rank, content, channel, message_kind, invite_room_code
    )
    VALUES (
        v_uid, v_code, v_display_name, v_avatar,
        v_rank, v_content, v_channel, v_kind, v_room_code
    )
    RETURNING * INTO v_inserted;

    RETURN to_jsonb(v_inserted);
END;
$$;
-- Effective permission history for public.send_diwan_message:
--   [018_diwan_live_chat.sql] REVOKE ALL ON FUNCTION public.send_diwan_message(TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
--   [018_diwan_live_chat.sql] GRANT EXECUTE ON FUNCTION public.send_diwan_message(TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.send_diwan_message(TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.send_diwan_message(TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- Function: public.submit_live_quiz_answer | latest: 019_guilds_and_live_arenas.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.submit_live_quiz_answer(
    p_session_id UUID,
    p_points_delta INTEGER,
    p_is_correct BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_pts INTEGER := LEAST(GREATEST(COALESCE(p_points_delta, 0), 0), 150);
    v_correct_inc INTEGER := CASE WHEN COALESCE(p_is_correct, FALSE) THEN 1 ELSE 0 END;
    v_row public.live_quiz_participants%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    UPDATE public.live_quiz_participants p
    SET score = p.score + v_pts,
        correct_count = p.correct_count + v_correct_inc
    WHERE p.session_id = p_session_id
      AND p.user_id = v_uid
    RETURNING * INTO v_row;

    RETURN to_jsonb(v_row);
END;
$$;
-- Effective permission history for public.submit_live_quiz_answer:
--   [019_guilds_and_live_arenas.sql] REVOKE ALL ON FUNCTION public.submit_live_quiz_answer(UUID, INTEGER, BOOLEAN) FROM PUBLIC;
--   [019_guilds_and_live_arenas.sql] GRANT EXECUTE ON FUNCTION public.submit_live_quiz_answer(UUID, INTEGER, BOOLEAN) TO authenticated, service_role;

-- Function: public.update_live_quiz_session_state | latest: 019_guilds_and_live_arenas.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.update_live_quiz_session_state(
    p_session_id UUID,
    p_status TEXT,
    p_question_index INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_status TEXT := CASE WHEN p_status IN ('waiting', 'active', 'finished') THEN p_status ELSE 'active' END;
    v_session public.live_quiz_sessions%ROWTYPE;
BEGIN
    UPDATE public.live_quiz_sessions s
    SET status = v_status,
        current_question_index = GREATEST(COALESCE(p_question_index, 0), 0)
    WHERE s.id = p_session_id
      AND s.host_id = v_uid
    RETURNING * INTO v_session;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'غير مصرح أو الجلسة غير موجودة';
    END IF;

    RETURN to_jsonb(v_session);
END;
$$;
-- Effective permission history for public.update_live_quiz_session_state:
--   [019_guilds_and_live_arenas.sql] REVOKE ALL ON FUNCTION public.update_live_quiz_session_state(UUID, TEXT, INTEGER) FROM PUBLIC;
--   [019_guilds_and_live_arenas.sql] GRANT EXECUTE ON FUNCTION public.update_live_quiz_session_state(UUID, TEXT, INTEGER) TO authenticated, service_role;
