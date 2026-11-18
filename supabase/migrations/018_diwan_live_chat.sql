-- ==============================================================================
-- 018: Diwan Al-Ahfad Live Chat, Challenge Invites, Moderation & 24h TTL
-- ==============================================================================
-- Complies strictly with AGENTS.md Rule #2:
--   - `#variable_conflict use_column` in every PL/pgSQL function
--   - `SET search_path = public, auth`
--   - Explicit table aliases and strict RLS (server-enforced profanity & 3s rate limit)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Core Tables: chat_messages, diwan_moderation, diwan_reports
-- ------------------------------------------------------------------------------
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

CREATE INDEX IF NOT EXISTS idx_chat_channel_created
    ON public.chat_messages (channel, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_user_created
    ON public.chat_messages (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.diwan_moderation (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    muted_until TIMESTAMPTZ,
    reason TEXT,
    updated_by UUID,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.diwan_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL DEFAULT 'مخالفة آداب الديوان',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (message_id, reporter_id)
);

-- Enable RLS strictly
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diwan_moderation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diwan_reports ENABLE ROW LEVEL SECURITY;

-- Public/authenticated can read active 24h chat messages (needed for Realtime subscription)
DROP POLICY IF EXISTS "Read diwan messages last 24h" ON public.chat_messages;
CREATE POLICY "Read diwan messages last 24h"
    ON public.chat_messages FOR SELECT
    TO anon, authenticated
    USING (created_at >= NOW() - INTERVAL '24 hours');

-- Note: Direct client INSERT is intentionally omitted so all inserts MUST pass
-- through `send_diwan_message` SECURITY DEFINER RPC (profanity, mute, flag & 3s limit).

DROP POLICY IF EXISTS "Reporters see own reports" ON public.diwan_reports;
CREATE POLICY "Reporters see own reports"
    ON public.diwan_reports FOR SELECT
    TO authenticated
    USING (auth.uid() = reporter_id OR public.check_is_admin());

DROP POLICY IF EXISTS "Admins manage diwan moderation" ON public.diwan_moderation;
CREATE POLICY "Admins manage diwan moderation"
    ON public.diwan_moderation FOR ALL
    TO authenticated
    USING (public.check_is_admin())
    WITH CHECK (public.check_is_admin());

-- Add chat_messages to Supabase Realtime cleanly
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN undefined_object THEN NULL;
END $$;

-- ------------------------------------------------------------------------------
-- 2. Server-side Ethics & Profanity Filter + Link Guard
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._diwan_contains_profanity(p_text TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_norm TEXT := LOWER(BTRIM(COALESCE(p_text, '')));
    v_compact TEXT;
    v_bad_words TEXT[] := ARRAY[
        'كلب', 'حمار', 'غبي', 'تافه', 'حقير', 'لعنة', 'يلعن', 'شرموط', 'قحبة',
        'ابن الكلب', 'منيك', 'كس', 'طيز', 'زبي', 'خنزير', 'سافل', 'منحط',
        'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'slut', 'whore', 'dick', 'pussy'
    ];
    v_w TEXT;
BEGIN
    IF v_norm = '' THEN
        RETURN FALSE;
    END IF;

    -- Block external spam links
    IF v_norm ~ '(https?://|www\.|t\.me/|discord\.gg)' THEN
        RETURN TRUE;
    END IF;

    v_compact := regexp_replace(v_norm, '[ـ\u064B-\u065F\s._*|-]+', '', 'g');

    FOREACH v_w IN ARRAY v_bad_words LOOP
        IF position(v_w IN v_norm) > 0 OR position(replace(v_w, ' ', '') IN v_compact) > 0 THEN
            RETURN TRUE;
        END IF;
    END LOOP;

    RETURN FALSE;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. `get_diwan_messages`: Reads active messages (last 24h) safely
-- ------------------------------------------------------------------------------
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

REVOKE ALL ON FUNCTION public.get_diwan_messages(TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_diwan_messages(TEXT, INTEGER) TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. `send_diwan_message`: Auth + Feature Flag + Mute + 3s Rate Limit + Filter + 24h TTL
-- ------------------------------------------------------------------------------
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
    v_flag_enabled BOOLEAN := TRUE;
    v_muted_until TIMESTAMPTZ;
    v_last_sent TIMESTAMPTZ;
    v_inserted public.chat_messages%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'يلزم تسجيل الدخول بحساب Google للمشاركة في الديوان';
    END IF;

    SELECT COALESCE((cfg.feature_flags->>'diwan_chat')::boolean, TRUE)
    INTO v_flag_enabled
    FROM public.app_release_config cfg
    WHERE cfg.platform = 'android'
    LIMIT 1;

    IF NOT COALESCE(v_flag_enabled, TRUE) THEN
        RAISE EXCEPTION 'ديوان الأحفاد متوقف مؤقتاً من الإدارة';
    END IF;

    SELECT dm.muted_until
    INTO v_muted_until
    FROM public.diwan_moderation dm
    WHERE dm.user_id = v_uid;

    IF v_muted_until IS NOT NULL AND v_muted_until > NOW() THEN
        RAISE EXCEPTION 'تم كتم مشاركتك في الديوان مؤقتاً بسبب مخالفة الآداب';
    END IF;

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

    -- 3-second cooldown per player
    SELECT MAX(cm.created_at)
    INTO v_last_sent
    FROM public.chat_messages cm
    WHERE cm.user_id = v_uid
      AND cm.created_at > NOW() - INTERVAL '3 seconds';

    IF v_last_sent IS NOT NULL THEN
        RAISE EXCEPTION 'انتظر 3 ثوانٍ قبل إرسال رسالة جديدة';
    END IF;

    -- Opportunistic lightweight 24h TTL pruning
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

REVOKE ALL ON FUNCTION public.send_diwan_message(TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_diwan_message(TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. `report_diwan_message` & `admin_moderate_diwan`
-- ------------------------------------------------------------------------------
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

REVOKE ALL ON FUNCTION public.report_diwan_message(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.report_diwan_message(UUID, TEXT) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_moderate_diwan(
    p_action TEXT,
    p_message_id UUID DEFAULT NULL,
    p_target_user_id UUID DEFAULT NULL,
    p_mute_hours INTEGER DEFAULT 24,
    p_reason TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_admin UUID := auth.uid();
    v_action TEXT := LOWER(BTRIM(COALESCE(p_action, '')));
    v_hours INTEGER := LEAST(GREATEST(COALESCE(p_mute_hours, 24), 1), 720);
    v_deleted INTEGER := 0;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_action = 'delete_message' AND p_message_id IS NOT NULL THEN
        DELETE FROM public.chat_messages cm WHERE cm.id = p_message_id;
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

    ELSIF v_action = 'mute_user' AND p_target_user_id IS NOT NULL THEN
        INSERT INTO public.diwan_moderation (user_id, muted_until, reason, updated_by, updated_at)
        VALUES (
            p_target_user_id,
            NOW() + make_interval(hours => v_hours),
            COALESCE(NULLIF(BTRIM(p_reason), ''), 'كتم إداري من الديوان'),
            v_admin,
            NOW()
        )
        ON CONFLICT (user_id) DO UPDATE
        SET muted_until = EXCLUDED.muted_until,
            reason = EXCLUDED.reason,
            updated_by = v_admin,
            updated_at = NOW();

    ELSIF v_action = 'unmute_user' AND p_target_user_id IS NOT NULL THEN
        DELETE FROM public.diwan_moderation dm WHERE dm.user_id = p_target_user_id;

    ELSIF v_action = 'cleanup_24h' THEN
        DELETE FROM public.chat_messages cm
        WHERE cm.created_at < NOW() - INTERVAL '24 hours';
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

    ELSE
        RAISE EXCEPTION 'Unsupported moderation action: %', v_action;
    END IF;

    PERFORM public._write_admin_audit_log(
        'diwan_moderation',
        'diwan',
        COALESCE(p_message_id::text, p_target_user_id::text, v_action),
        COALESCE(NULLIF(BTRIM(p_reason), ''), 'إجراء إشرافي في الديوان: ' || v_action),
        jsonb_build_object('action', v_action, 'deleted', v_deleted, 'mute_hours', v_hours)
    );

    RETURN jsonb_build_object('ok', TRUE, 'action', v_action, 'deleted_count', v_deleted);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_moderate_diwan(TEXT, UUID, UUID, INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_moderate_diwan(TEXT, UUID, UUID, INTEGER, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 6. Enable `diwan_chat` feature flag now that 018 schema is ready
-- ------------------------------------------------------------------------------
UPDATE public.app_release_config cfg
SET feature_flags = jsonb_set(
        COALESCE(cfg.feature_flags, '{}'::jsonb),
        '{diwan_chat}',
        'true'::jsonb,
        true
    ),
    updated_at = NOW()
WHERE cfg.platform = 'android';
