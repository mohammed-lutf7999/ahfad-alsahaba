-- ==============================================================================
-- 017: Royal Inbox, Compensation Inbox Notifications, Resource Health & Cleanup
-- ==============================================================================
-- Strictly complies with AGENTS.md Rule #2:
--   - `#variable_conflict use_column` in all PL/pgSQL functions
--   - `SET search_path = public, auth`
--   - `SECURITY DEFINER` with explicit `REVOKE ALL / GRANT EXECUTE`
--   - Zero stub code; safe for Supabase Free Plan (`500 MB DB`, `200 Realtime`)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Seed new feature_flags cleanly without overwriting existing toggles
-- ------------------------------------------------------------------------------
UPDATE public.app_release_config cfg
SET feature_flags = jsonb_build_object(
        'royal_inbox', TRUE,
        'live_announcement_ping', TRUE,
        'wise_teacher_mode', TRUE,
        'diwan_chat', FALSE,
        'guilds_arenas', FALSE
    ) || COALESCE(cfg.feature_flags, '{}'::jsonb),
    updated_at = NOW()
WHERE cfg.platform = 'android';

-- ------------------------------------------------------------------------------
-- 2. Royal Inbox RPC: `get_player_inbox` (On-Demand, zero background cost)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_player_inbox(
    p_player_code TEXT DEFAULT NULL,
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
    v_raw_code TEXT := UPPER(BTRIM(COALESCE(p_player_code, '')));
    v_valid_code TEXT := NULL;
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 25), 1), 50);
    v_items JSONB := '[]'::jsonb;
BEGIN
    IF v_raw_code ~ '^SAH-[A-Z0-9]{4,8}$' AND LENGTH(v_raw_code) BETWEEN 8 AND 12 THEN
        v_valid_code := v_raw_code;
    END IF;

    IF v_uid IS NULL AND v_valid_code IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT COALESCE(
        jsonb_agg(to_jsonb(t) ORDER BY t.is_read ASC, t.created_at DESC),
        '[]'::jsonb
    )
    INTO v_items
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
            ann.is_active,
            ann.min_version_code,
            ann.max_version_code,
            ann.expires_at,
            ann.created_at,
            EXISTS (
                SELECT 1
                FROM public.user_announcement_receipts rec
                WHERE rec.announcement_id = ann.id
                  AND (
                      (v_uid IS NOT NULL AND (rec.recipient_key = ('uid:' || v_uid::text) OR rec.user_id = v_uid))
                      OR (v_valid_code IS NOT NULL AND (rec.recipient_key = ('code:' || v_valid_code) OR rec.player_code = v_valid_code))
                  )
            ) AS is_read,
            (
                ann.title LIKE '%🎁%'
                OR ann.title LIKE '%تعويض%'
                OR ann.title LIKE '%هدية%'
            ) AS is_reward_notice
        FROM public.admin_announcements ann
        WHERE ann.is_active = TRUE
          AND (ann.starts_at IS NULL OR ann.starts_at <= NOW())
          AND (ann.expires_at IS NULL OR ann.expires_at > NOW())
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
        ORDER BY is_read ASC, ann.created_at DESC
        LIMIT v_limit
    ) t;

    RETURN v_items;
END;
$$;

REVOKE ALL ON FUNCTION public.get_player_inbox(TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_player_inbox(TEXT, INTEGER) TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. `mark_all_inbox_read`: Idempotent bulk read marker
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_all_inbox_read(
    p_player_code TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_raw_code TEXT := UPPER(BTRIM(COALESCE(p_player_code, '')));
    v_valid_code TEXT := NULL;
    v_marked INTEGER := 0;
    v_ann RECORD;
BEGIN
    IF v_raw_code ~ '^SAH-[A-Z0-9]{4,8}$' AND LENGTH(v_raw_code) BETWEEN 8 AND 12 THEN
        v_valid_code := v_raw_code;
    END IF;

    IF v_uid IS NULL AND v_valid_code IS NULL THEN
        RETURN 0;
    END IF;

    FOR v_ann IN
        SELECT ann.id
        FROM public.admin_announcements ann
        WHERE ann.is_active = TRUE
          AND (ann.starts_at IS NULL OR ann.starts_at <= NOW())
          AND (ann.expires_at IS NULL OR ann.expires_at > NOW())
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
        LIMIT 50
    LOOP
        IF v_uid IS NOT NULL THEN
            INSERT INTO public.user_announcement_receipts (
                announcement_id, recipient_key, user_id, player_code, seen_at, acknowledged_at
            )
            VALUES (
                v_ann.id, 'uid:' || v_uid::text, v_uid, v_valid_code, NOW(), NOW()
            )
            ON CONFLICT (announcement_id, recipient_key) DO UPDATE
            SET acknowledged_at = NOW();
        END IF;

        IF v_valid_code IS NOT NULL THEN
            INSERT INTO public.user_announcement_receipts (
                announcement_id, recipient_key, user_id, player_code, seen_at, acknowledged_at
            )
            VALUES (
                v_ann.id, 'code:' || v_valid_code, v_uid, v_valid_code, NOW(), NOW()
            )
            ON CONFLICT (announcement_id, recipient_key) DO UPDATE
            SET acknowledged_at = NOW();
        END IF;

        v_marked := v_marked + 1;
    END LOOP;

    RETURN v_marked;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_all_inbox_read(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_all_inbox_read(TEXT) TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. Upgrade `admin_grant_player_compensation` to also send an Inbox notice
-- ------------------------------------------------------------------------------
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
    v_admin_uid UUID := auth.uid();
    v_coins INTEGER := COALESCE(p_coins_delta, 0);
    v_gems INTEGER := COALESCE(p_gems_delta, 0);
    v_xp INTEGER := COALESCE(p_xp_delta, 0);
    v_reason TEXT := BTRIM(COALESCE(p_reason, ''));
    v_before RECORD;
    v_after RECORD;
    v_player_code TEXT := NULL;
    v_parts TEXT[] := ARRAY[]::TEXT[];
    v_summary TEXT := '';
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'Target user_id is required for compensation';
    END IF;

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

    SELECT pd.player_code
    INTO v_player_code
    FROM public.player_directory pd
    WHERE pd.user_id = p_user_id
    ORDER BY pd.last_seen_at DESC NULLS LAST
    LIMIT 1;

    IF v_coins > 0 THEN
        v_parts := array_append(v_parts, v_coins::text || ' دينار 🪙');
    END IF;
    IF v_gems > 0 THEN
        v_parts := array_append(v_parts, v_gems::text || ' ياقوتة 💎');
    END IF;
    IF v_xp > 0 THEN
        v_parts := array_append(v_parts, v_xp::text || ' نقطة خبرة ⭐');
    END IF;
    v_summary := array_to_string(v_parts, ' و ');

    INSERT INTO public.admin_announcements (
        title,
        body,
        message_type,
        target_scope,
        target_user_id,
        target_player_code,
        cta_label,
        cta_route,
        is_dismissible,
        is_active,
        expires_at,
        created_by,
        updated_at
    )
    VALUES (
        '🎁 هدية وتعويض من الإدارة',
        'تمت إضافة ' || v_summary || ' إلى رصيدك بنجاح.' || E'\n' || 'السبب: ' || v_reason,
        'admin',
        'single_user',
        p_user_id,
        v_player_code,
        'سوق الفرسان',
        '/knights-store',
        TRUE,
        TRUE,
        NOW() + INTERVAL '30 days',
        v_admin_uid,
        NOW()
    );

    PERFORM public._write_admin_audit_log(
        'grant_player_compensation',
        'player',
        p_user_id::text,
        v_reason,
        jsonb_build_object(
            'coins_delta', v_coins,
            'gems_delta', v_gems,
            'xp_delta', v_xp,
            'inbox_notified', TRUE,
            'before', jsonb_build_object('coins', v_before.coins, 'gems', v_before.gems, 'total_score', v_before.total_score, 'player_level', v_before.player_level),
            'after', jsonb_build_object('coins', v_after.coins, 'gems', v_after.gems, 'total_score', v_after.total_score, 'player_level', v_after.player_level)
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'user_id', p_user_id,
        'player_code', v_player_code,
        'coins', v_after.coins,
        'gems', v_after.gems,
        'total_score', v_after.total_score,
        'player_level', v_after.player_level
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_grant_player_compensation(UUID, INTEGER, INTEGER, INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_grant_player_compensation(UUID, INTEGER, INTEGER, INTEGER, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. `admin_get_resource_health`: Live Postgres size, top tables & activity
-- ------------------------------------------------------------------------------
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

REVOKE ALL ON FUNCTION public.admin_get_resource_health() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_resource_health() TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 6. `admin_cleanup_stale_resources`: Safe admin cleanup with audit trail
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

