-- ==============================================================================
-- 019: Clans/Guilds ("معركة الجمعة الكبرى") & Live Kahoot Arenas (up to 100p)
-- ==============================================================================
-- Complies strictly with AGENTS.md Rule #2:
--   - `#variable_conflict use_column` in every PL/pgSQL function
--   - `SET search_path = public, auth`
--   - Atomic row locks, RLS isolation, and Free Plan stale session cleanup
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Core Tables: guilds, guild_members, live_quiz_sessions, live_quiz_participants
-- ------------------------------------------------------------------------------
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

CREATE TABLE IF NOT EXISTS public.guild_members (
    guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT 'فارس',
    avatar_index INTEGER NOT NULL DEFAULT 0,
    role TEXT NOT NULL DEFAULT 'عضو' CHECK (role IN ('قائد', 'نائب', 'عضو')),
    weekly_contribution INTEGER NOT NULL DEFAULT 0,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_guilds_weekly_score
    ON public.guilds (weekly_score DESC, total_score DESC);

CREATE INDEX IF NOT EXISTS idx_guild_members_guild_id
    ON public.guild_members (guild_id, weekly_contribution DESC);

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

CREATE INDEX IF NOT EXISTS idx_live_sessions_pin
    ON public.live_quiz_sessions (pin_code);

CREATE INDEX IF NOT EXISTS idx_live_participants_score
    ON public.live_quiz_participants (session_id, score DESC);

-- RLS Policies
ALTER TABLE public.guilds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_quiz_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_quiz_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public view guilds" ON public.guilds;
CREATE POLICY "Public view guilds"
    ON public.guilds FOR SELECT
    TO anon, authenticated
    USING (TRUE);

DROP POLICY IF EXISTS "Public view guild members" ON public.guild_members;
CREATE POLICY "Public view guild members"
    ON public.guild_members FOR SELECT
    TO anon, authenticated
    USING (TRUE);

DROP POLICY IF EXISTS "Authenticated view live sessions" ON public.live_quiz_sessions;
CREATE POLICY "Authenticated view live sessions"
    ON public.live_quiz_sessions FOR SELECT
    TO authenticated
    USING (TRUE);

DROP POLICY IF EXISTS "Authenticated view live participants" ON public.live_quiz_participants;
CREATE POLICY "Authenticated view live participants"
    ON public.live_quiz_participants FOR SELECT
    TO authenticated
    USING (TRUE);

-- ------------------------------------------------------------------------------
-- 2. Guilds RPCs: create_guild, join_guild, leave_guild, contribute_guild_score, get_guilds_overview
-- ------------------------------------------------------------------------------
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

REVOKE ALL ON FUNCTION public.create_guild(TEXT, TEXT, INTEGER, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_guild(TEXT, TEXT, INTEGER, TEXT, INTEGER) TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.join_guild(UUID, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_guild(UUID, TEXT, INTEGER) TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.leave_guild() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.leave_guild() TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.contribute_guild_score(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.contribute_guild_score(INTEGER) TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.get_guilds_overview(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_guilds_overview(INTEGER) TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. Live Quiz Arenas RPCs (PIN rooms up to 100 participants)
-- ------------------------------------------------------------------------------
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

REVOKE ALL ON FUNCTION public.create_live_quiz_session(TEXT, TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_live_quiz_session(TEXT, TEXT, JSONB) TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.join_live_quiz_session(TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_live_quiz_session(TEXT, TEXT, INTEGER) TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.submit_live_quiz_answer(UUID, INTEGER, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_live_quiz_answer(UUID, INTEGER, BOOLEAN) TO authenticated, service_role;

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

REVOKE ALL ON FUNCTION public.update_live_quiz_session_state(UUID, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_live_quiz_session_state(UUID, TEXT, INTEGER) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. Upgrade Resource Health & Stale Cleanup with Expired Live Sessions & Old Chat
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_cleanup_stale_resources(
    p_action TEXT,
    p_older_than_days INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_action TEXT := LOWER(BTRIM(COALESCE(p_action, '')));
    v_days INTEGER := LEAST(GREATEST(COALESCE(p_older_than_days, 30), 7), 365);
    v_deleted INTEGER := 0;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_action = 'finished_matches' THEN
        DELETE FROM public.matches m
        WHERE m.status IN ('finished', 'cancelled')
          AND m.created_at < NOW() - make_interval(days => v_days)
          AND NOT EXISTS (
              SELECT 1 FROM public.ghost_recordings gr WHERE gr.source_match_id = m.id
          );
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

    ELSIF v_action = 'expired_receipts' THEN
        DELETE FROM public.user_announcement_receipts rec
        USING public.admin_announcements ann
        WHERE rec.announcement_id = ann.id
          AND (
              (ann.expires_at IS NOT NULL AND ann.expires_at < NOW() - INTERVAL '7 days')
              OR (ann.is_active = FALSE AND ann.updated_at < NOW() - make_interval(days => v_days))
          );
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

    ELSIF v_action = 'expired_live_sessions' THEN
        DELETE FROM public.live_quiz_sessions s
        WHERE s.status = 'finished'
           OR s.expires_at < NOW();
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

    ELSIF v_action = 'old_chat_messages' THEN
        DELETE FROM public.chat_messages cm
        WHERE cm.created_at < NOW() - INTERVAL '24 hours';
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

    ELSIF v_action = 'reset_guild_week' THEN
        UPDATE public.guilds g SET weekly_score = 0;
        UPDATE public.guild_members gm SET weekly_contribution = 0;
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

    ELSIF v_action = 'old_audit_logs' THEN
        DELETE FROM public.admin_audit_logs al
        WHERE al.created_at < NOW() - make_interval(days => GREATEST(v_days, 90));
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

    ELSE
        RAISE EXCEPTION 'Unsupported cleanup action: %', v_action;
    END IF;

    PERFORM public._write_admin_audit_log(
        'cleanup_stale_resources',
        'system_resources',
        v_action,
        'تنظيف دوري لمساحة قاعدة البيانات (' || v_days::text || ' يوماً)',
        jsonb_build_object('action', v_action, 'older_than_days', v_days, 'deleted_count', v_deleted)
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'action', v_action,
        'deleted_count', v_deleted,
        'db_size_bytes', pg_database_size(current_database())
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_cleanup_stale_resources(TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_cleanup_stale_resources(TEXT, INTEGER) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. Enable `guilds_arenas` feature flag cleanly on Android release config
-- ------------------------------------------------------------------------------
UPDATE public.app_release_config cfg
SET feature_flags = jsonb_set(
        COALESCE(cfg.feature_flags, '{}'::jsonb),
        '{guilds_arenas}',
        'true'::jsonb,
        true
    ),
    updated_at = NOW()
WHERE cfg.platform = 'android';
