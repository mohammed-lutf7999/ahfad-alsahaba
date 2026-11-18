-- ==============================================================================
-- 020: External Push Token Registry (FCM Bridge) & Inbox Deep-Link Targets
-- ==============================================================================
-- Complies strictly with AGENTS.md Rule #2:
--   - `#variable_conflict use_column` in all PL/pgSQL functions
--   - `SET search_path = public, auth`
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.player_push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    player_code TEXT,
    device_token TEXT NOT NULL UNIQUE,
    provider TEXT NOT NULL DEFAULT 'fcm' CHECK (provider IN ('fcm', 'local')),
    platform TEXT NOT NULL DEFAULT 'android',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_user
    ON public.player_push_tokens (user_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_push_tokens_code
    ON public.player_push_tokens (player_code)
    WHERE is_active = TRUE;

ALTER TABLE public.player_push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own push tokens" ON public.player_push_tokens;
CREATE POLICY "Users manage own push tokens"
    ON public.player_push_tokens FOR ALL
    TO authenticated
    USING (auth.uid() = user_id OR public.check_is_admin())
    WITH CHECK (auth.uid() = user_id OR public.check_is_admin());

CREATE OR REPLACE FUNCTION public.register_player_push_token(
    p_device_token TEXT,
    p_player_code TEXT DEFAULT NULL,
    p_provider TEXT DEFAULT 'fcm',
    p_platform TEXT DEFAULT 'android'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_token TEXT := BTRIM(COALESCE(p_device_token, ''));
    v_code TEXT := NULLIF(UPPER(BTRIM(COALESCE(p_player_code, ''))), '');
    v_provider TEXT := CASE WHEN p_provider IN ('fcm', 'local') THEN p_provider ELSE 'fcm' END;
    v_platform TEXT := LEFT(COALESCE(NULLIF(BTRIM(p_platform), ''), 'android'), 20);
BEGIN
    IF char_length(v_token) < 16 OR char_length(v_token) > 512 THEN
        RAISE EXCEPTION 'Invalid device push token length';
    END IF;

    IF v_code IS NOT NULL AND v_code !~ '^SAH-[A-Z0-9]{4,8}$' THEN
        v_code := NULL;
    END IF;

    IF v_uid IS NULL AND v_code IS NULL THEN
        RAISE EXCEPTION 'Either authenticated user or valid player_code is required';
    END IF;

    INSERT INTO public.player_push_tokens (
        user_id, player_code, device_token, provider, platform, is_active, updated_at
    )
    VALUES (
        v_uid, v_code, v_token, v_provider, v_platform, TRUE, NOW()
    )
    ON CONFLICT (device_token) DO UPDATE
    SET user_id = COALESCE(EXCLUDED.user_id, public.player_push_tokens.user_id),
        player_code = COALESCE(EXCLUDED.player_code, public.player_push_tokens.player_code),
        provider = EXCLUDED.provider,
        platform = EXCLUDED.platform,
        is_active = TRUE,
        updated_at = NOW();

    RETURN jsonb_build_object('ok', TRUE, 'provider', v_provider, 'platform', v_platform);
END;
$$;

REVOKE ALL ON FUNCTION public.register_player_push_token(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_player_push_token(TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_get_push_targets(
    p_player_code TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
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
    v_tokens JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'user_id', t.user_id,
                'player_code', t.player_code,
                'device_token', t.device_token,
                'provider', t.provider,
                'platform', t.platform,
                'updated_at', t.updated_at
            )
            ORDER BY t.updated_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_tokens
    FROM (
        SELECT pt.user_id, pt.player_code, pt.device_token, pt.provider, pt.platform, pt.updated_at
        FROM public.player_push_tokens pt
        WHERE pt.is_active = TRUE
          AND (p_user_id IS NULL OR pt.user_id = p_user_id)
          AND (v_code IS NULL OR pt.player_code = v_code)
        ORDER BY pt.updated_at DESC
        LIMIT 500
    ) t;

    RETURN v_tokens;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_push_targets(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_push_targets(TEXT, UUID) TO authenticated, service_role;
