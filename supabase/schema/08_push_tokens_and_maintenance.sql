-- ============================================================================
-- AUTO-GENERATED CANONICAL SCHEMA REFERENCE — DO NOT EDIT MANUALLY!
-- Domain: 08_push_tokens_and_maintenance.sql (رموز الإشعارات FCM، مراقبة صحة الموارد، والتنظيف الآلي)
-- Source: supabase/migrations/001..023 (23 migrations)
-- Generator: python tools/export_supabase_schema.py
-- Summary: 1 tables | 1 RLS policies | 2 indexes | 0 triggers | 6 functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLES & COLUMN/CONSTRAINT EVOLUTION
-- ----------------------------------------------------------------------------

-- Table: public.player_push_tokens (origin: 020_push_tokens_and_inbox_routing.sql)
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
-- Effective ALTERs for public.player_push_tokens:
--   [020_push_tokens_and_inbox_routing.sql]
ALTER TABLE public.player_push_tokens ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. ACTIVE RLS POLICIES
-- ----------------------------------------------------------------------------

-- Policy: "Users manage own push tokens" ON public.player_push_tokens (latest: 020_push_tokens_and_inbox_routing.sql)
CREATE POLICY "Users manage own push tokens"
    ON public.player_push_tokens FOR ALL
    TO authenticated
    USING (auth.uid() = user_id OR public.check_is_admin())
    WITH CHECK (auth.uid() = user_id OR public.check_is_admin());

-- ----------------------------------------------------------------------------
-- 3. ACTIVE INDEXES
-- ----------------------------------------------------------------------------

-- Index: idx_push_tokens_code ON public.player_push_tokens (origin: 020_push_tokens_and_inbox_routing.sql)
CREATE INDEX IF NOT EXISTS idx_push_tokens_code
    ON public.player_push_tokens (player_code)
    WHERE is_active = TRUE;

-- Index: idx_push_tokens_user ON public.player_push_tokens (origin: 020_push_tokens_and_inbox_routing.sql)
CREATE INDEX IF NOT EXISTS idx_push_tokens_user
    ON public.player_push_tokens (user_id)
    WHERE is_active = TRUE;

-- ----------------------------------------------------------------------------
-- 5. LATEST EFFECTIVE FUNCTIONS & RPCs
-- ----------------------------------------------------------------------------

-- Function: public.admin_cleanup_stale_resources | latest: 019_guilds_and_live_arenas.sql | redefinitions: 2 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_cleanup_stale_resources:
--   [017_inbox_and_resource_health.sql] REVOKE ALL ON FUNCTION public.admin_cleanup_stale_resources(TEXT, INTEGER) FROM PUBLIC;
--   [017_inbox_and_resource_health.sql] GRANT EXECUTE ON FUNCTION public.admin_cleanup_stale_resources(TEXT, INTEGER) TO authenticated, service_role;
--   [019_guilds_and_live_arenas.sql] REVOKE ALL ON FUNCTION public.admin_cleanup_stale_resources(TEXT, INTEGER) FROM PUBLIC;
--   [019_guilds_and_live_arenas.sql] GRANT EXECUTE ON FUNCTION public.admin_cleanup_stale_resources(TEXT, INTEGER) TO authenticated, service_role;

-- Function: public.admin_get_push_targets | latest: 020_push_tokens_and_inbox_routing.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_get_push_targets:
--   [020_push_tokens_and_inbox_routing.sql] REVOKE ALL ON FUNCTION public.admin_get_push_targets(TEXT, UUID) FROM PUBLIC;
--   [020_push_tokens_and_inbox_routing.sql] GRANT EXECUTE ON FUNCTION public.admin_get_push_targets(TEXT, UUID) TO authenticated, service_role;

-- Function: public.admin_get_resource_health | latest: 017_inbox_and_resource_health.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_get_resource_health()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_db_bytes BIGINT := pg_database_size(current_database());
    v_db_limit_bytes BIGINT := 524288000; -- 500 MB Supabase Free Plan database cap
    v_active_matches_now INTEGER := 0;
    v_active_players_5m INTEGER := 0;
    v_active_players_60m INTEGER := 0;
    v_active_players_24h INTEGER := 0;
    v_total_directory INTEGER := 0;
    v_old_matches_count INTEGER := 0;
    v_expired_receipts_count INTEGER := 0;
    v_tables JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COUNT(*) INTO v_active_matches_now
    FROM public.matches m
    WHERE m.status IN ('waiting', 'matched', 'ready', 'playing')
      AND m.created_at > NOW() - INTERVAL '2 hours';

    SELECT COUNT(*) INTO v_active_players_5m
    FROM public.player_directory pd
    WHERE pd.last_seen_at > NOW() - INTERVAL '5 minutes';

    SELECT COUNT(*) INTO v_active_players_60m
    FROM public.player_directory pd
    WHERE pd.last_seen_at > NOW() - INTERVAL '60 minutes';

    SELECT COUNT(*) INTO v_active_players_24h
    FROM public.player_directory pd
    WHERE pd.last_seen_at > NOW() - INTERVAL '24 hours';

    SELECT COUNT(*) INTO v_total_directory
    FROM public.player_directory;

    SELECT COUNT(*) INTO v_old_matches_count
    FROM public.matches m
    WHERE m.status IN ('finished', 'cancelled')
      AND m.created_at < NOW() - INTERVAL '30 days'
      AND NOT EXISTS (
          SELECT 1 FROM public.ghost_recordings gr WHERE gr.source_match_id = m.id
      );

    SELECT COUNT(*) INTO v_expired_receipts_count
    FROM public.user_announcement_receipts rec
    JOIN public.admin_announcements ann ON ann.id = rec.announcement_id
    WHERE (ann.expires_at IS NOT NULL AND ann.expires_at < NOW() - INTERVAL '7 days')
       OR (ann.is_active = FALSE AND ann.updated_at < NOW() - INTERVAL '30 days');

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'table_name', t.table_name,
                'size_bytes', t.size_bytes,
                'row_estimate', t.row_estimate
            )
            ORDER BY t.size_bytes DESC
        ),
        '[]'::jsonb
    )
    INTO v_tables
    FROM (
        SELECT
            c.relname AS table_name,
            pg_total_relation_size(c.oid) AS size_bytes,
            COALESCE(st.n_live_tup, 0) AS row_estimate
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_stat_user_tables st ON st.relid = c.oid
        WHERE n.nspname = 'public'
          AND c.relkind = 'r'
        ORDER BY pg_total_relation_size(c.oid) DESC
        LIMIT 12
    ) t;

    RETURN jsonb_build_object(
        'db_size_bytes', v_db_bytes,
        'db_limit_bytes', v_db_limit_bytes,
        'db_usage_percent', ROUND((v_db_bytes::numeric / v_db_limit_bytes::numeric) * 100.0, 2),
        'active_matches_now', v_active_matches_now,
        'active_players_5m', v_active_players_5m,
        'active_players_60m', v_active_players_60m,
        'active_players_24h', v_active_players_24h,
        'total_directory_players', v_total_directory,
        'cleanable_old_matches', v_old_matches_count,
        'cleanable_expired_receipts', v_expired_receipts_count,
        'tables', v_tables,
        'measured_at', NOW()
    );
END;
$$;
-- Effective permission history for public.admin_get_resource_health:
--   [017_inbox_and_resource_health.sql] REVOKE ALL ON FUNCTION public.admin_get_resource_health() FROM PUBLIC;
--   [017_inbox_and_resource_health.sql] GRANT EXECUTE ON FUNCTION public.admin_get_resource_health() TO authenticated, service_role;

-- Function: public.cleanup_stale_matches | latest: 005_maintenance_functions.sql | redefinitions: 1 | security_definer: True | search_path: False
CREATE OR REPLACE FUNCTION cleanup_stale_matches()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete matches older than 24 hours that are not finished
  DELETE FROM matches 
  WHERE created_at < NOW() - INTERVAL '24 hours'
  AND status != 'finished';
  
  -- Also clean up participants for those matches (cascade should handle it, but good to be safe)
  -- Assuming CASCADE delete is set up on foreign keys. If not, we'd delete from participants first.
END;
$$;
-- Effective permission history for public.cleanup_stale_matches:
--   [005_maintenance_functions.sql] GRANT EXECUTE ON FUNCTION cleanup_stale_matches() TO authenticated;
--   [005_maintenance_functions.sql] GRANT EXECUTE ON FUNCTION cleanup_stale_matches() TO service_role;

-- Function: public.cleanup_stale_queue | latest: 005_maintenance_functions.sql | redefinitions: 1 | security_definer: True | search_path: False
CREATE OR REPLACE FUNCTION cleanup_stale_queue()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete players waiting for more than 1 hour (probably disconnected)
  DELETE FROM matchmaking_queue
  WHERE created_at < NOW() - INTERVAL '1 hour';
END;
$$;
-- Effective permission history for public.cleanup_stale_queue:
--   [005_maintenance_functions.sql] GRANT EXECUTE ON FUNCTION cleanup_stale_queue() TO authenticated;
--   [005_maintenance_functions.sql] GRANT EXECUTE ON FUNCTION cleanup_stale_queue() TO service_role;

-- Function: public.register_player_push_token | latest: 020_push_tokens_and_inbox_routing.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.register_player_push_token:
--   [020_push_tokens_and_inbox_routing.sql] REVOKE ALL ON FUNCTION public.register_player_push_token(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
--   [020_push_tokens_and_inbox_routing.sql] GRANT EXECUTE ON FUNCTION public.register_player_push_token(TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
