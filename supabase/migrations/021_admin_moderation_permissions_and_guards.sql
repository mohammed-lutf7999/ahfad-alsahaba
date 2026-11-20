-- ==============================================================================
-- 021: Dynamic Player Permissions, Ban/Mute Governance, Social Moderation Queue
--      & Strict Server-Side Feature-Flag Enforcement (Plan 11 — M15)
-- ==============================================================================
-- Complies strictly with AGENTS.md Rule #2:
--   - `#variable_conflict use_column` in EVERY PL/pgSQL function
--   - `SET search_path = public, auth` in EVERY function
--   - Explicit table aliases and exact signature parity (zero PGRST203 overloads)
--   - `app_admins` keyed strictly by `email` (never `user_id`)
--   - `live_arena_host_restricted` defaults to TRUE (protects 200 Realtime cap)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Core Table: public.player_permissions
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.player_permissions (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    player_code TEXT,
    is_banned BOOLEAN NOT NULL DEFAULT FALSE,
    banned_until TIMESTAMPTZ,
    ban_reason TEXT NOT NULL DEFAULT '',
    can_use_online BOOLEAN NOT NULL DEFAULT TRUE,
    can_use_diwan BOOLEAN NOT NULL DEFAULT TRUE,
    can_use_guilds BOOLEAN NOT NULL DEFAULT TRUE,
    can_host_live_arenas BOOLEAN DEFAULT NULL,
    notes TEXT NOT NULL DEFAULT '',
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_player_permissions_banned
    ON public.player_permissions (is_banned)
    WHERE is_banned = TRUE;

ALTER TABLE public.player_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Players read own permissions" ON public.player_permissions;
CREATE POLICY "Players read own permissions"
    ON public.player_permissions FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id OR public.check_is_admin());

DROP POLICY IF EXISTS "Admins manage player permissions" ON public.player_permissions;
CREATE POLICY "Admins manage player permissions"
    ON public.player_permissions FOR ALL
    TO authenticated
    USING (public.check_is_admin())
    WITH CHECK (public.check_is_admin());

-- ------------------------------------------------------------------------------
-- 2. Internal Helpers: _is_user_admin, _get_effective_player_permissions,
--    _assert_player_allowed
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._is_user_admin(p_uid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
BEGIN
    IF p_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM auth.users au
        JOIN public.app_admins aa
          ON LOWER(aa.email) = LOWER(BTRIM(au.email))
        WHERE au.id = p_uid
    );
END;
$$;

REVOKE ALL ON FUNCTION public._is_user_admin(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._is_user_admin(UUID) TO service_role;

CREATE OR REPLACE FUNCTION public._get_effective_player_permissions(p_uid UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_is_admin BOOLEAN := FALSE;
    v_flags JSONB := '{}'::jsonb;
    v_guilds_arenas_flag BOOLEAN := TRUE;
    v_host_restricted_flag BOOLEAN := TRUE;
    v_pp RECORD;
    v_has_pp BOOLEAN := FALSE;
    v_dm RECORD;
    v_has_dm BOOLEAN := FALSE;
    v_is_banned BOOLEAN := FALSE;
    v_is_diwan_muted BOOLEAN := FALSE;
    v_can_use_online BOOLEAN := TRUE;
    v_can_use_diwan BOOLEAN := TRUE;
    v_can_use_guilds BOOLEAN := TRUE;
    v_raw_host_override BOOLEAN := NULL;
    v_effective_host BOOLEAN := FALSE;
BEGIN
    -- Guest / anonymous safe default (never throws on NULL)
    IF p_uid IS NULL THEN
        RETURN jsonb_build_object(
            'is_banned', FALSE,
            'banned_until', NULL,
            'ban_reason', '',
            'is_diwan_muted', FALSE,
            'diwan_muted_until', NULL,
            'diwan_mute_reason', '',
            'can_use_online', TRUE,
            'can_use_diwan', FALSE,
            'can_use_guilds', FALSE,
            'can_host_live_arenas', NULL,
            'effective_can_host_live_arenas', FALSE,
            'notes', ''
        );
    END IF;

    SELECT COALESCE(cfg.feature_flags, '{}'::jsonb)
    INTO v_flags
    FROM public.app_release_config cfg
    WHERE cfg.platform = 'android'
    LIMIT 1;

    v_guilds_arenas_flag := COALESCE((v_flags->>'guilds_arenas')::boolean, TRUE);
    v_host_restricted_flag := COALESCE((v_flags->>'live_arena_host_restricted')::boolean, TRUE);
    v_is_admin := public._is_user_admin(p_uid);

    SELECT
        pp.is_banned,
        pp.banned_until,
        pp.ban_reason,
        pp.can_use_online,
        pp.can_use_diwan,
        pp.can_use_guilds,
        pp.can_host_live_arenas,
        pp.notes
    INTO v_pp
    FROM public.player_permissions pp
    WHERE pp.user_id = p_uid
    LIMIT 1;
    v_has_pp := FOUND;

    SELECT dm.muted_until, dm.reason
    INTO v_dm
    FROM public.diwan_moderation dm
    WHERE dm.user_id = p_uid
    LIMIT 1;
    v_has_dm := FOUND;

    IF v_has_pp THEN
        v_is_banned := (NOT v_is_admin)
            AND COALESCE(v_pp.is_banned, FALSE)
            AND (v_pp.banned_until IS NULL OR v_pp.banned_until > NOW());
        v_can_use_online := v_is_admin OR COALESCE(v_pp.can_use_online, TRUE);
        v_can_use_diwan := v_is_admin OR COALESCE(v_pp.can_use_diwan, TRUE);
        v_can_use_guilds := v_is_admin OR COALESCE(v_pp.can_use_guilds, TRUE);
        v_raw_host_override := v_pp.can_host_live_arenas;
    END IF;

    IF v_has_dm THEN
        v_is_diwan_muted := (NOT v_is_admin)
            AND (v_dm.muted_until IS NOT NULL AND v_dm.muted_until > NOW());
    END IF;

    -- Truth table (Plan 11 Section 2.b)
    IF NOT v_guilds_arenas_flag THEN
        v_effective_host := FALSE;
    ELSIF v_is_banned THEN
        v_effective_host := FALSE;
    ELSIF v_is_admin THEN
        v_effective_host := TRUE;
    ELSE
        v_effective_host := COALESCE(v_raw_host_override, NOT v_host_restricted_flag);
    END IF;

    RETURN jsonb_build_object(
        'is_banned', v_is_banned,
        'banned_until', CASE WHEN v_is_banned THEN v_pp.banned_until ELSE NULL END,
        'ban_reason', CASE WHEN v_is_banned THEN COALESCE(v_pp.ban_reason, '') ELSE '' END,
        'is_diwan_muted', v_is_diwan_muted,
        'diwan_muted_until', CASE WHEN v_is_diwan_muted THEN v_dm.muted_until ELSE NULL END,
        'diwan_mute_reason', CASE WHEN v_is_diwan_muted THEN COALESCE(v_dm.reason, '') ELSE '' END,
        'can_use_online', v_can_use_online,
        'can_use_diwan', v_can_use_diwan,
        'can_use_guilds', v_can_use_guilds,
        'can_host_live_arenas', v_raw_host_override,
        'effective_can_host_live_arenas', v_effective_host,
        'notes', CASE WHEN v_has_pp THEN COALESCE(v_pp.notes, '') ELSE '' END
    );
END;
$$;

REVOKE ALL ON FUNCTION public._get_effective_player_permissions(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._get_effective_player_permissions(UUID) TO service_role;

CREATE OR REPLACE FUNCTION public._assert_player_allowed(
    p_uid UUID,
    p_scope TEXT
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_scope TEXT := LOWER(BTRIM(COALESCE(p_scope, '')));
    v_is_admin BOOLEAN := public._is_user_admin(p_uid);
    v_flags JSONB := '{}'::jsonb;
    v_perms JSONB := public._get_effective_player_permissions(p_uid);
    v_ban_reason TEXT := BTRIM(COALESCE(v_perms->>'ban_reason', ''));
BEGIN
    IF COALESCE((v_perms->>'is_banned')::boolean, FALSE) THEN
        IF v_ban_reason <> '' THEN
            RAISE EXCEPTION 'تم حظر حسابك من الإدارة: %', v_ban_reason;
        ELSE
            RAISE EXCEPTION 'تم حظر حسابك مؤقتاً أو دائماً من الإدارة';
        END IF;
    END IF;

    SELECT COALESCE(cfg.feature_flags, '{}'::jsonb)
    INTO v_flags
    FROM public.app_release_config cfg
    WHERE cfg.platform = 'android'
    LIMIT 1;

    IF v_scope = 'online' THEN
        IF NOT v_is_admin AND NOT COALESCE((v_flags->>'online_multiplayer')::boolean, TRUE) THEN
            RAISE EXCEPTION 'المباريات الأونلاين متوقفة مؤقتاً للصيانة';
        END IF;
        IF NOT COALESCE((v_perms->>'can_use_online')::boolean, TRUE) THEN
            RAISE EXCEPTION 'تم منعك من اللعب الأونلاين من الإدارة';
        END IF;

    ELSIF v_scope = 'ghost_match' THEN
        IF NOT v_is_admin AND NOT COALESCE((v_flags->>'online_multiplayer')::boolean, TRUE) THEN
            RAISE EXCEPTION 'المباريات الأونلاين متوقفة مؤقتاً للصيانة';
        END IF;
        IF NOT v_is_admin AND NOT COALESCE((v_flags->>'ghost_matches')::boolean, TRUE) THEN
            RAISE EXCEPTION 'معارك الأشباح متوقفة مؤقتاً من الإدارة';
        END IF;
        IF NOT COALESCE((v_perms->>'can_use_online')::boolean, TRUE) THEN
            RAISE EXCEPTION 'تم منعك من اللعب الأونلاين من الإدارة';
        END IF;

    ELSIF v_scope = 'private_room' THEN
        IF NOT v_is_admin AND NOT COALESCE((v_flags->>'private_rooms')::boolean, TRUE) THEN
            RAISE EXCEPTION 'غرف التحدي الخاصة متوقفة مؤقتاً للصيانة';
        END IF;
        IF NOT COALESCE((v_perms->>'can_use_online')::boolean, TRUE) THEN
            RAISE EXCEPTION 'تم منعك من اللعب الأونلاين والغرف الخاصة من الإدارة';
        END IF;

    ELSIF v_scope = 'diwan' THEN
        IF NOT v_is_admin AND NOT COALESCE((v_flags->>'diwan_chat')::boolean, TRUE) THEN
            RAISE EXCEPTION 'ديوان الأحفاد متوقف مؤقتاً من الإدارة';
        END IF;
        IF NOT COALESCE((v_perms->>'can_use_diwan')::boolean, TRUE) THEN
            RAISE EXCEPTION 'تم منعك من المشاركة في ديوان الأحفاد من الإدارة';
        END IF;
        IF COALESCE((v_perms->>'is_diwan_muted')::boolean, FALSE) THEN
            RAISE EXCEPTION 'تم كتم مشاركتك في الديوان مؤقتاً بسبب مخالفة الآداب';
        END IF;

    ELSIF v_scope = 'guilds' THEN
        IF NOT v_is_admin AND NOT COALESCE((v_flags->>'guilds_arenas')::boolean, TRUE) THEN
            RAISE EXCEPTION 'نظام الكتائب والبطولات الجماعية متوقف مؤقتاً من الإدارة';
        END IF;
        IF NOT COALESCE((v_perms->>'can_use_guilds')::boolean, TRUE) THEN
            RAISE EXCEPTION 'تم منعك من استخدام نظام الكتائب من الإدارة';
        END IF;

    ELSIF v_scope = 'live_arena_join' THEN
        IF NOT v_is_admin AND NOT COALESCE((v_flags->>'guilds_arenas')::boolean, TRUE) THEN
            RAISE EXCEPTION 'نظام الكتائب والبطولات الجماعية متوقف مؤقتاً من الإدارة';
        END IF;

    ELSIF v_scope = 'host_live_arena' THEN
        IF NOT v_is_admin AND NOT COALESCE((v_flags->>'guilds_arenas')::boolean, TRUE) THEN
            RAISE EXCEPTION 'نظام الكتائب والبطولات الجماعية متوقف مؤقتاً من الإدارة';
        END IF;
        IF NOT COALESCE((v_perms->>'effective_can_host_live_arenas')::boolean, FALSE) THEN
            IF v_perms->>'can_host_live_arenas' = 'false' THEN
                RAISE EXCEPTION 'تم منعك فردياً من إنشاء البطولات الحية من الإدارة';
            ELSE
                RAISE EXCEPTION 'إنشاء البطولات الحية محصور حالياً بالمعلمين والمشرفين المعتمدين';
            END IF;
        END IF;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public._assert_player_allowed(UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._assert_player_allowed(UUID, TEXT) TO service_role;

-- ------------------------------------------------------------------------------
-- 3. Upgrade `get_app_control_state` (always includes lightweight player_permissions)
-- ------------------------------------------------------------------------------
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
    v_perms JSONB := public._get_effective_player_permissions(v_uid);
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

    -- Fast short-circuit path: ALWAYS returns `player_permissions` for <1s single-player enforcement
    -- without bumping global `config_version` for innocent users.
    IF COALESCE(p_client_config_version, 0) > 0
       AND COALESCE(v_config.config_version, 1) = p_client_config_version
       AND jsonb_array_length(v_personal_announcements) = 0 THEN
        RETURN jsonb_build_object(
            'changed', FALSE,
            'config_version', COALESCE(v_config.config_version, 1),
            'cms_version', COALESCE(v_config.cms_version, 1),
            'is_admin', v_is_admin,
            'player_permissions', (v_perms - 'notes'),
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
        'player_permissions', (v_perms - 'notes'),
        'server_time', NOW(),
        'release_config', jsonb_build_object(
            'platform', COALESCE(v_config.platform, 'android'),
            'min_version_code', COALESCE(v_config.min_version_code, 1),
            'latest_version_code', COALESCE(v_config.latest_version_code, 21),
            'latest_version_name', COALESCE(v_config.latest_version_name, '1.1.0'),
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

REVOKE ALL ON FUNCTION public.get_app_control_state(TEXT, INTEGER, BIGINT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_app_control_state(TEXT, INTEGER, BIGINT, TEXT) TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. Upgrade `admin_get_player_detail` (adds `permissions` & `diwan_moderation`)
-- ------------------------------------------------------------------------------
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
    v_permissions JSONB := NULL;
    v_diwan_mod JSONB := NULL;
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

        v_permissions := public._get_effective_player_permissions(v_uid);

        SELECT jsonb_build_object(
            'user_id', dm.user_id,
            'muted_until', dm.muted_until,
            'reason', COALESCE(dm.reason, ''),
            'is_active', (dm.muted_until IS NOT NULL AND dm.muted_until > NOW()),
            'updated_at', dm.updated_at
        )
        INTO v_diwan_mod
        FROM public.diwan_moderation dm
        WHERE dm.user_id = v_uid
        LIMIT 1;
    END IF;

    RETURN jsonb_build_object(
        'user_id', v_uid,
        'player_code', COALESCE(v_code, v_dir->>'player_code'),
        'directory', v_dir,
        'progress', v_prog,
        'leaderboard', v_lb,
        'inventory', v_inventory,
        'recent_matches', v_matches,
        'permissions', v_permissions,
        'diwan_moderation', v_diwan_mod
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_player_detail(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_player_detail(UUID, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. Server-Side Flag & Permission Enforcement on Existing RPCs
-- ------------------------------------------------------------------------------

-- 5.1 `get_player_inbox`: enforces `royal_inbox` feature flag (admins bypass)
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
    v_is_admin BOOLEAN := public.check_is_admin();
    v_inbox_enabled BOOLEAN := TRUE;
    v_raw_code TEXT := UPPER(BTRIM(COALESCE(p_player_code, '')));
    v_valid_code TEXT := NULL;
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 25), 1), 50);
    v_items JSONB := '[]'::jsonb;
BEGIN
    SELECT COALESCE((cfg.feature_flags->>'royal_inbox')::boolean, TRUE)
    INTO v_inbox_enabled
    FROM public.app_release_config cfg
    WHERE cfg.platform = 'android'
    LIMIT 1;

    IF NOT v_is_admin AND NOT COALESCE(v_inbox_enabled, TRUE) THEN
        RETURN '[]'::jsonb;
    END IF;

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

-- 5.2 `find_or_create_match` (exact signature from 014) + online/ban guard
CREATE OR REPLACE FUNCTION public.find_or_create_match(
    p_user_id UUID,
    p_app_version TEXT DEFAULT '1.0.13',
    p_trophies INT DEFAULT 1000,
    p_last_opponent_id UUID DEFAULT NULL
)
RETURNS TABLE(match_id UUID, player1_id UUID, player2_id UUID, seed BIGINT, question_ids TEXT[])
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_opponent_id UUID;
    v_match_id UUID;
    v_seed BIGINT;
    v_question_ids TEXT[];
    v_queue_id UUID;
    v_self_trophies INT := 1000;
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_user_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    PERFORM public._assert_player_allowed(p_user_id, 'online');

    SELECT COALESCE(
        (SELECT lb.trophies FROM public.leaderboard AS lb WHERE lb.user_id = p_user_id LIMIT 1),
        p_trophies,
        1000
    ) INTO v_self_trophies;

    DELETE FROM public.matchmaking_queue AS q
    WHERE q.updated_at < NOW() - INTERVAL '15 seconds';

    UPDATE public.matches AS m
    SET status = 'finished'
    WHERE (m.player1_id = p_user_id OR m.player2_id = p_user_id)
      AND m.status NOT IN ('finished', 'cancelled')
      AND m.is_private = FALSE;

    SELECT q.id, q.user_id
    INTO v_queue_id, v_opponent_id
    FROM public.matchmaking_queue AS q
    WHERE q.user_id != p_user_id
      AND q.updated_at > NOW() - INTERVAL '15 seconds'
      AND (p_last_opponent_id IS NULL OR q.user_id != p_last_opponent_id)
      AND ABS(COALESCE(q.trophies, 1000) - v_self_trophies) <= (100 + (EXTRACT(EPOCH FROM (NOW() - q.created_at)) * 25))
    ORDER BY
      ABS(COALESCE(q.trophies, 1000) - v_self_trophies) ASC,
      q.created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    IF v_opponent_id IS NULL THEN
        SELECT q.id, q.user_id
        INTO v_queue_id, v_opponent_id
        FROM public.matchmaking_queue AS q
        WHERE q.user_id != p_user_id
          AND q.updated_at > NOW() - INTERVAL '15 seconds'
          AND (p_last_opponent_id IS NULL OR q.user_id != p_last_opponent_id)
          AND q.created_at < NOW() - INTERVAL '8 seconds'
        ORDER BY q.created_at ASC
        LIMIT 1
        FOR UPDATE SKIP LOCKED;
    END IF;

    IF v_opponent_id IS NOT NULL THEN
        DELETE FROM public.matchmaking_queue AS q WHERE q.id = v_queue_id;
        DELETE FROM public.matchmaking_queue AS q WHERE q.user_id = p_user_id;

        UPDATE public.matches AS m
        SET status = 'finished'
        WHERE (m.player1_id = v_opponent_id OR m.player2_id = v_opponent_id)
          AND m.status NOT IN ('finished', 'cancelled')
          AND m.is_private = FALSE;

        v_seed := FLOOR(RANDOM() * 2147483647)::BIGINT;
        v_question_ids := public.generate_match_question_ids();

        INSERT INTO public.matches (
            player1_id, player2_id, seed, status, question_ids,
            current_question, is_private, is_ghost_match, created_at
        )
        VALUES (
            v_opponent_id, p_user_id, v_seed, 'matched', v_question_ids,
            0, FALSE, FALSE, NOW()
        )
        RETURNING id INTO v_match_id;

        INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score, current_question_index)
        VALUES
            (v_match_id, v_opponent_id, FALSE, 0, 0),
            (v_match_id, p_user_id, FALSE, 0, 0);

        RETURN QUERY SELECT v_match_id, v_opponent_id, p_user_id, v_seed, v_question_ids;
    ELSE
        INSERT INTO public.matchmaking_queue (user_id, app_version, trophies, updated_at, created_at)
        VALUES (p_user_id, COALESCE(p_app_version, '1.0.13'), v_self_trophies, NOW(), NOW())
        ON CONFLICT (user_id) DO UPDATE SET
            app_version = EXCLUDED.app_version,
            trophies = EXCLUDED.trophies,
            updated_at = NOW();

        RETURN;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.find_or_create_match(UUID, TEXT, INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_or_create_match(UUID, TEXT, INT, UUID) TO authenticated, anon, service_role;

-- 5.3 `find_or_create_ghost_match` (exact 13-column signature from 014) + ban/online/ghost guard
CREATE OR REPLACE FUNCTION public.find_or_create_ghost_match(
    p_user_id UUID,
    p_trophies INT DEFAULT 1000
)
RETURNS TABLE(
    match_id UUID,
    ghost_user_id UUID,
    ghost_name TEXT,
    ghost_avatar_index INT,
    ghost_frame TEXT,
    ghost_level INT,
    ghost_trophies INT,
    seed BIGINT,
    question_ids TEXT[],
    timeline JSONB,
    is_friendly BOOLEAN,
    daily_ghost_count INT,
    is_human_match BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_daily_count INT := 0;
    v_is_friendly BOOLEAN := FALSE;
    v_ghost RECORD;
    v_new_match_id UUID;
    v_self_trophies INT := 1000;
    v_recent_match RECORD;
    v_opp_id UUID;
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_user_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    PERFORM public._assert_player_allowed(p_user_id, 'ghost_match');

    DELETE FROM public.matchmaking_queue AS q WHERE q.user_id = p_user_id;

    SELECT m.id, m.player1_id, m.player2_id, m.seed, m.question_ids
    INTO v_recent_match
    FROM public.matches AS m
    JOIN public.match_participants AS mp
      ON mp.match_id = m.id AND mp.user_id = p_user_id
    WHERE (m.player1_id = p_user_id OR m.player2_id = p_user_id)
      AND COALESCE(m.is_ghost_match, FALSE) = FALSE
      AND COALESCE(m.is_private, FALSE) = FALSE
      AND m.status IN ('matched', 'ready')
      AND mp.finished_at IS NULL
      AND m.created_at > NOW() - INTERVAL '25 seconds'
    ORDER BY m.created_at DESC
    LIMIT 1;

    IF v_recent_match.id IS NOT NULL THEN
        v_opp_id := CASE
            WHEN v_recent_match.player1_id = p_user_id THEN v_recent_match.player2_id
            ELSE v_recent_match.player1_id
        END;

        RETURN QUERY SELECT
            v_recent_match.id,
            v_opp_id,
            NULL::TEXT,
            NULL::INT,
            NULL::TEXT,
            NULL::INT,
            NULL::INT,
            v_recent_match.seed,
            v_recent_match.question_ids,
            NULL::JSONB,
            FALSE,
            0,
            TRUE;
        RETURN;
    END IF;

    SELECT COALESCE(
        (SELECT lb.trophies FROM public.leaderboard AS lb WHERE lb.user_id = p_user_id LIMIT 1),
        p_trophies,
        1000
    ) INTO v_self_trophies;

    UPDATE public.matches AS m
    SET status = 'finished'
    WHERE m.player1_id = p_user_id
      AND m.status NOT IN ('finished', 'cancelled')
      AND m.is_private = FALSE;

    SELECT COUNT(DISTINCT m.id)
    INTO v_daily_count
    FROM public.matches AS m
    WHERE m.player1_id = p_user_id
      AND m.is_ghost_match = TRUE
      AND m.created_at >= CURRENT_DATE::TIMESTAMPTZ;

    IF v_daily_count >= 15 THEN
        v_is_friendly := TRUE;
    END IF;

    SELECT g.id, g.user_id, g.display_name, g.avatar_index, g.equipped_frame,
           g.player_level, g.trophies, g.seed, g.question_ids, g.timeline, g.total_score
    INTO v_ghost
    FROM public.ghost_recordings AS g
    WHERE g.is_active = TRUE
      AND (g.user_id IS NULL OR g.user_id != p_user_id)
      AND g.id NOT IN (
          SELECT COALESCE(m.source_ghost_recording_id, '00000000-0000-0000-0000-000000000000'::UUID)
          FROM public.matches AS m
          WHERE m.player1_id = p_user_id
            AND m.is_ghost_match = TRUE
            AND m.created_at > NOW() - INTERVAL '2 hours'
      )
    ORDER BY
      (g.user_id IS NOT NULL) DESC,
      ABS(g.trophies - v_self_trophies) ASC,
      g.use_count ASC,
      RANDOM()
    LIMIT 1;

    IF v_ghost.id IS NULL THEN
        SELECT g.id, g.user_id, g.display_name, g.avatar_index, g.equipped_frame,
               g.player_level, g.trophies, g.seed, g.question_ids, g.timeline, g.total_score
        INTO v_ghost
        FROM public.ghost_recordings AS g
        WHERE g.is_active = TRUE
          AND (g.user_id IS NULL OR g.user_id != p_user_id)
        ORDER BY
          (g.user_id IS NOT NULL) DESC,
          ABS(g.trophies - v_self_trophies) ASC,
          g.use_count ASC,
          RANDOM()
        LIMIT 1;
    END IF;

    IF v_ghost.id IS NULL THEN
        RAISE EXCEPTION 'لا توجد تسجيلات أشباح متوفرة حالياً';
    END IF;

    UPDATE public.ghost_recordings AS g
    SET use_count = g.use_count + 1
    WHERE g.id = v_ghost.id;

    INSERT INTO public.matches (
        player1_id, player2_id, seed, status, question_ids,
        current_question, is_private, is_ghost_match, source_ghost_recording_id,
        is_friendly, ghost_score, created_at
    )
    VALUES (
        p_user_id, NULL, v_ghost.seed, 'matched', v_ghost.question_ids,
        0, FALSE, TRUE, v_ghost.id,
        v_is_friendly, COALESCE(v_ghost.total_score, 0), NOW()
    )
    RETURNING id INTO v_new_match_id;

    INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score, current_question_index)
    VALUES (v_new_match_id, p_user_id, TRUE, 0, 0);

    RETURN QUERY SELECT
        v_new_match_id,
        v_ghost.user_id,
        v_ghost.display_name,
        v_ghost.avatar_index,
        v_ghost.equipped_frame,
        v_ghost.player_level,
        v_ghost.trophies,
        v_ghost.seed,
        v_ghost.question_ids,
        v_ghost.timeline,
        v_is_friendly,
        v_daily_count,
        FALSE;
END;
$$;

REVOKE ALL ON FUNCTION public.find_or_create_ghost_match(UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_or_create_ghost_match(UUID, INT) TO authenticated, anon, service_role;

-- 5.4 `create_private_room` (exact signature from 014) + ban/online/private_room guard
CREATE OR REPLACE FUNCTION public.create_private_room(p_host_id UUID)
RETURNS TABLE(match_id UUID, room_code VARCHAR, expires_at TIMESTAMPTZ, seed BIGINT, question_ids TEXT[])
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_match_id UUID;
    v_code VARCHAR(6);
    v_expires TIMESTAMPTZ;
    v_seed BIGINT;
    v_questions TEXT[];
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_host_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    PERFORM public._assert_player_allowed(p_host_id, 'private_room');

    UPDATE public.matches AS m
    SET status = 'finished'
    WHERE m.player1_id = p_host_id
      AND m.status = 'waiting'
      AND m.is_private = TRUE;

    LOOP
        v_code := LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.matches AS m
            WHERE m.room_code = v_code
              AND m.status = 'waiting'
              AND m.expires_at > NOW()
        );
    END LOOP;

    v_expires := NOW() + INTERVAL '3 minutes';
    v_seed := FLOOR(RANDOM() * 2147483647)::BIGINT;
    v_questions := public.generate_match_question_ids();

    INSERT INTO public.matches (
        player1_id, seed, question_ids, status,
        is_private, is_ghost_match, room_code, expires_at, created_at
    )
    VALUES (
        p_host_id, v_seed, v_questions, 'waiting',
        TRUE, FALSE, v_code, v_expires, NOW()
    )
    RETURNING id INTO v_match_id;

    INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score)
    VALUES (v_match_id, p_host_id, TRUE, 0);

    RETURN QUERY SELECT v_match_id, v_code, v_expires, v_seed, v_questions;
END;
$$;

REVOKE ALL ON FUNCTION public.create_private_room(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_private_room(UUID) TO authenticated, anon, service_role;

-- 5.5 `join_private_room` (exact signature from 011) + auth.uid + search_path + ban/private_room guard
CREATE OR REPLACE FUNCTION public.join_private_room(
    p_room_code VARCHAR(6),
    p_guest_id UUID
)
RETURNS TABLE (
    match_id UUID,
    host_id UUID,
    seed BIGINT,
    question_ids TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_match RECORD;
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_guest_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    PERFORM public._assert_player_allowed(p_guest_id, 'private_room');

    SELECT m.id, m.player1_id, m.seed, m.question_ids, m.player2_id
    INTO v_match
    FROM public.matches AS m
    WHERE m.room_code = p_room_code
      AND m.status = 'waiting'
      AND m.is_private = TRUE
      AND m.expires_at > NOW()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'الغرفة غير موجودة أو انتهت مهلتها الزمنية';
    END IF;

    IF v_match.player1_id = p_guest_id THEN
        RAISE EXCEPTION 'لا يمكنك الانضمام لغرفة أنشأتها أنت بنفسك';
    END IF;

    IF v_match.player2_id IS NOT NULL THEN
        RAISE EXCEPTION 'الغرفة مكتملة بالفعل';
    END IF;

    UPDATE public.matches AS m
    SET player2_id = p_guest_id, status = 'matched'
    WHERE m.id = v_match.id;

    INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score)
    VALUES (v_match.id, p_guest_id, TRUE, 0);

    RETURN QUERY SELECT v_match.id, v_match.player1_id, v_match.seed, v_match.question_ids;
END;
$$;

REVOKE ALL ON FUNCTION public.join_private_room(VARCHAR, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_private_room(VARCHAR, UUID) TO authenticated, anon, service_role;

-- 5.6 `create_instant_rematch` (exact signature from 014) + ban/online guard
CREATE OR REPLACE FUNCTION public.create_instant_rematch(
    p_parent_match_id UUID,
    p_user_id UUID
)
RETURNS TABLE(match_id UUID, player1_id UUID, player2_id UUID, seed BIGINT, question_ids TEXT[], is_friendly BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_old_match RECORD;
    v_existing_rematch RECORD;
    v_new_match_id UUID;
    v_new_seed BIGINT;
    v_new_questions TEXT[];
    v_rematch_count INT := 0;
    v_is_friendly BOOLEAN := FALSE;
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_user_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    PERFORM public._assert_player_allowed(p_user_id, 'online');

    SELECT m.id, m.player1_id, m.player2_id, COALESCE(m.rematch_count, 0) AS count
    INTO v_old_match
    FROM public.matches AS m
    WHERE m.id = p_parent_match_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'المباراة الأصلية غير موجودة';
    END IF;

    IF v_old_match.player1_id != p_user_id AND v_old_match.player2_id != p_user_id THEN
        RAISE EXCEPTION 'غير مصرح لك بتجديد هذه المباراة';
    END IF;

    SELECT m.id, m.player1_id, m.player2_id, m.seed, m.question_ids, (COALESCE(m.rematch_count, 0) >= 3) AS friendly
    INTO v_existing_rematch
    FROM public.matches AS m
    WHERE m.parent_match_id = p_parent_match_id
    LIMIT 1;

    IF v_existing_rematch.id IS NOT NULL THEN
        RETURN QUERY SELECT
            v_existing_rematch.id,
            v_existing_rematch.player1_id,
            v_existing_rematch.player2_id,
            v_existing_rematch.seed,
            v_existing_rematch.question_ids,
            v_existing_rematch.friendly;
        RETURN;
    END IF;

    v_rematch_count := v_old_match.count + 1;
    IF v_rematch_count >= 3 THEN
        v_is_friendly := TRUE;
    END IF;

    v_new_seed := FLOOR(RANDOM() * 2147483647)::BIGINT;
    v_new_questions := public.generate_match_question_ids();

    INSERT INTO public.matches (
        parent_match_id, player1_id, player2_id, seed, question_ids,
        status, is_ghost_match, rematch_count, created_at
    )
    VALUES (
        p_parent_match_id, v_old_match.player1_id, v_old_match.player2_id, v_new_seed, v_new_questions,
        'matched', FALSE, v_rematch_count, NOW()
    )
    RETURNING id INTO v_new_match_id;

    INSERT INTO public.match_participants (match_id, user_id, current_score, is_ready)
    VALUES
        (v_new_match_id, v_old_match.player1_id, 0, FALSE),
        (v_new_match_id, v_old_match.player2_id, 0, FALSE);

    RETURN QUERY SELECT
        v_new_match_id,
        v_old_match.player1_id,
        v_old_match.player2_id,
        v_new_seed,
        v_new_questions,
        v_is_friendly;
END;
$$;

REVOKE ALL ON FUNCTION public.create_instant_rematch(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_instant_rematch(UUID, UUID) TO authenticated, anon, service_role;

-- 5.7 `send_diwan_message`: adds `is_banned` + `can_use_diwan` via `_assert_player_allowed`
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

REVOKE ALL ON FUNCTION public.send_diwan_message(TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_diwan_message(TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- 5.8 `create_guild` & `join_guild`: enforce `guilds_arenas` + `is_banned` + `can_use_guilds`
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

REVOKE ALL ON FUNCTION public.join_guild(UUID, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_guild(UUID, TEXT, INTEGER) TO authenticated, service_role;

-- 5.9 `create_live_quiz_session` & `join_live_quiz_session`: enforce dynamic host policy + flag + ban
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

REVOKE ALL ON FUNCTION public.join_live_quiz_session(TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_live_quiz_session(TEXT, TEXT, INTEGER) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 6. Admin Governance RPCs: Permissions, Diwan Queue, Guilds & Live Arenas
-- ------------------------------------------------------------------------------

-- 6.1 `admin_upsert_player_permissions`
CREATE OR REPLACE FUNCTION public.admin_upsert_player_permissions(
    p_user_id UUID,
    p_is_banned BOOLEAN DEFAULT FALSE,
    p_ban_hours INTEGER DEFAULT NULL,
    p_ban_reason TEXT DEFAULT '',
    p_can_use_online BOOLEAN DEFAULT TRUE,
    p_can_use_diwan BOOLEAN DEFAULT TRUE,
    p_can_use_guilds BOOLEAN DEFAULT TRUE,
    p_can_host_live_arenas BOOLEAN DEFAULT NULL,
    p_notes TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_admin_uid UUID := auth.uid();
    v_is_banned BOOLEAN := COALESCE(p_is_banned, FALSE);
    v_banned_until TIMESTAMPTZ := NULL;
    v_reason TEXT := LEFT(BTRIM(COALESCE(p_ban_reason, '')), 200);
    v_notes TEXT := LEFT(BTRIM(COALESCE(p_notes, '')), 240);
    v_player_code TEXT := NULL;
    v_effective JSONB;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'Target user_id is required';
    END IF;

    -- Crucial safety guard: prevent accidentally banning any admin (keyed by email in app_admins!)
    IF v_is_banned AND public._is_user_admin(p_user_id) THEN
        RAISE EXCEPTION 'لا يمكن حظر حساب مشرف في لوحة الإدارة';
    END IF;

    IF v_is_banned THEN
        IF p_ban_hours IS NOT NULL AND p_ban_hours > 0 THEN
            v_banned_until := NOW() + make_interval(hours => LEAST(p_ban_hours, 8760));
        ELSE
            v_banned_until := NULL;
        END IF;
    ELSE
        v_banned_until := NULL;
        v_reason := '';
    END IF;

    SELECT pd.player_code
    INTO v_player_code
    FROM public.player_directory pd
    WHERE pd.user_id = p_user_id
    ORDER BY pd.last_seen_at DESC NULLS LAST
    LIMIT 1;

    INSERT INTO public.player_permissions (
        user_id,
        player_code,
        is_banned,
        banned_until,
        ban_reason,
        can_use_online,
        can_use_diwan,
        can_use_guilds,
        can_host_live_arenas,
        notes,
        updated_by,
        updated_at
    )
    VALUES (
        p_user_id,
        v_player_code,
        v_is_banned,
        v_banned_until,
        v_reason,
        COALESCE(p_can_use_online, TRUE),
        COALESCE(p_can_use_diwan, TRUE),
        COALESCE(p_can_use_guilds, TRUE),
        p_can_host_live_arenas,
        v_notes,
        v_admin_uid,
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET player_code = COALESCE(EXCLUDED.player_code, public.player_permissions.player_code),
        is_banned = EXCLUDED.is_banned,
        banned_until = EXCLUDED.banned_until,
        ban_reason = EXCLUDED.ban_reason,
        can_use_online = EXCLUDED.can_use_online,
        can_use_diwan = EXCLUDED.can_use_diwan,
        can_use_guilds = EXCLUDED.can_use_guilds,
        can_host_live_arenas = EXCLUDED.can_host_live_arenas,
        notes = EXCLUDED.notes,
        updated_by = v_admin_uid,
        updated_at = NOW();

    v_effective := public._get_effective_player_permissions(p_user_id);

    PERFORM public._write_admin_audit_log(
        'upsert_player_permissions',
        'player_permissions',
        p_user_id::text,
        COALESCE(NULLIF(v_reason, ''), NULLIF(v_notes, ''), 'تحديث صلاحيات/حظر لاعب'),
        jsonb_build_object(
            'player_code', v_player_code,
            'is_banned', v_is_banned,
            'ban_hours', p_ban_hours,
            'can_use_online', COALESCE(p_can_use_online, TRUE),
            'can_use_diwan', COALESCE(p_can_use_diwan, TRUE),
            'can_use_guilds', COALESCE(p_can_use_guilds, TRUE),
            'can_host_live_arenas', p_can_host_live_arenas
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'user_id', p_user_id,
        'player_code', v_player_code,
        'permissions', v_effective
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_player_permissions(UUID, BOOLEAN, INTEGER, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_player_permissions(UUID, BOOLEAN, INTEGER, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, TEXT) TO authenticated, service_role;

-- 6.2 `admin_list_diwan_moderation_queue`
CREATE OR REPLACE FUNCTION public.admin_list_diwan_moderation_queue(
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
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
    v_reports JSONB := '[]'::jsonb;
    v_muted JSONB := '[]'::jsonb;
    v_recent JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY r.latest_reported_at DESC), '[]'::jsonb)
    INTO v_reports
    FROM (
        SELECT
            dr.message_id,
            cm.user_id AS sender_id,
            cm.display_name AS sender_name,
            cm.player_code AS sender_code,
            cm.content,
            cm.channel,
            cm.created_at AS message_created_at,
            COUNT(dr.id)::integer AS reports_count,
            MAX(dr.created_at) AS latest_reported_at,
            (ARRAY_AGG(dr.reason ORDER BY dr.created_at DESC))[1] AS latest_reason
        FROM public.diwan_reports dr
        JOIN public.chat_messages cm ON cm.id = dr.message_id
        GROUP BY
            dr.message_id, cm.user_id, cm.display_name, cm.player_code,
            cm.content, cm.channel, cm.created_at
        ORDER BY MAX(dr.created_at) DESC
        LIMIT v_limit
    ) r;

    SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.muted_until DESC), '[]'::jsonb)
    INTO v_muted
    FROM (
        SELECT
            dm.user_id,
            COALESCE(pd.display_name, 'لاعب') AS display_name,
            pd.player_code,
            dm.muted_until,
            COALESCE(dm.reason, '') AS reason,
            dm.updated_at
        FROM public.diwan_moderation dm
        LEFT JOIN LATERAL (
            SELECT pd0.display_name, pd0.player_code
            FROM public.player_directory pd0
            WHERE pd0.user_id = dm.user_id
            ORDER BY pd0.last_seen_at DESC NULLS LAST
            LIMIT 1
        ) pd ON TRUE
        WHERE dm.muted_until IS NOT NULL
          AND dm.muted_until > NOW()
        ORDER BY dm.muted_until DESC
        LIMIT v_limit
    ) m;

    SELECT COALESCE(jsonb_agg(to_jsonb(cm_row) ORDER BY cm_row.created_at DESC), '[]'::jsonb)
    INTO v_recent
    FROM (
        SELECT
            cm.id,
            cm.user_id,
            cm.player_code,
            cm.display_name,
            cm.user_rank,
            cm.content,
            cm.channel,
            cm.message_kind,
            cm.created_at
        FROM public.chat_messages cm
        WHERE cm.created_at >= NOW() - INTERVAL '24 hours'
        ORDER BY cm.created_at DESC
        LIMIT 25
    ) cm_row;

    RETURN jsonb_build_object(
        'reports', v_reports,
        'muted_users', v_muted,
        'recent_messages', v_recent
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_diwan_moderation_queue(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_diwan_moderation_queue(INTEGER) TO authenticated, service_role;

-- 6.3 Upgrade `admin_moderate_diwan` (adds `dismiss_reports` & returns `player_code` for targeted ping)
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
    v_player_code TEXT := NULL;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF p_target_user_id IS NOT NULL THEN
        SELECT pd.player_code
        INTO v_player_code
        FROM public.player_directory pd
        WHERE pd.user_id = p_target_user_id
        ORDER BY pd.last_seen_at DESC NULLS LAST
        LIMIT 1;
    END IF;

    IF v_action = 'delete_message' AND p_message_id IS NOT NULL THEN
        DELETE FROM public.chat_messages cm WHERE cm.id = p_message_id;
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

    ELSIF v_action = 'dismiss_reports' AND p_message_id IS NOT NULL THEN
        DELETE FROM public.diwan_reports dr WHERE dr.message_id = p_message_id;
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

    ELSIF v_action = 'mute_user' AND p_target_user_id IS NOT NULL THEN
        IF public._is_user_admin(p_target_user_id) THEN
            RAISE EXCEPTION 'لا يمكن كتم حساب مشرف';
        END IF;
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
        GET DIAGNOSTICS v_deleted = ROW_COUNT;

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
        jsonb_build_object(
            'action', v_action,
            'deleted', v_deleted,
            'mute_hours', v_hours,
            'player_code', v_player_code
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'action', v_action,
        'deleted_count', v_deleted,
        'target_user_id', p_target_user_id,
        'player_code', v_player_code
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_moderate_diwan(TEXT, UUID, UUID, INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_moderate_diwan(TEXT, UUID, UUID, INTEGER, TEXT) TO authenticated, service_role;

-- 6.4 `admin_list_guilds_and_arenas`
CREATE OR REPLACE FUNCTION public.admin_list_guilds_and_arenas(
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
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
    v_guilds JSONB := '[]'::jsonb;
    v_sessions JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COALESCE(jsonb_agg(to_jsonb(gt) ORDER BY gt.weekly_score DESC, gt.created_at DESC), '[]'::jsonb)
    INTO v_guilds
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
            COALESCE(pd.display_name, gm_lead.display_name, 'قائد') AS leader_name,
            COUNT(DISTINCT gm.user_id)::integer AS members_count,
            g.created_at
        FROM public.guilds g
        LEFT JOIN public.guild_members gm ON gm.guild_id = g.id
        LEFT JOIN public.guild_members gm_lead ON gm_lead.guild_id = g.id AND gm_lead.user_id = g.leader_id
        LEFT JOIN LATERAL (
            SELECT pd0.display_name
            FROM public.player_directory pd0
            WHERE pd0.user_id = g.leader_id
            ORDER BY pd0.last_seen_at DESC NULLS LAST
            LIMIT 1
        ) pd ON TRUE
        GROUP BY g.id, pd.display_name, gm_lead.display_name
        ORDER BY g.weekly_score DESC, g.created_at DESC
        LIMIT v_limit
    ) gt;

    SELECT COALESCE(
        jsonb_agg(
            to_jsonb(st)
            ORDER BY
                CASE WHEN st.status IN ('waiting', 'active') THEN 0 ELSE 1 END ASC,
                st.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_sessions
    FROM (
        SELECT
            s.id,
            s.pin_code,
            s.title,
            s.category_id,
            s.host_id,
            COALESCE(pd.display_name, 'مضيف') AS host_name,
            s.status,
            s.current_question_index,
            s.participants_count,
            s.expires_at,
            s.created_at
        FROM public.live_quiz_sessions s
        LEFT JOIN LATERAL (
            SELECT pd0.display_name
            FROM public.player_directory pd0
            WHERE pd0.user_id = s.host_id
            ORDER BY pd0.last_seen_at DESC NULLS LAST
            LIMIT 1
        ) pd ON TRUE
        ORDER BY
            CASE WHEN s.status IN ('waiting', 'active') THEN 0 ELSE 1 END ASC,
            s.created_at DESC
        LIMIT v_limit
    ) st;

    RETURN jsonb_build_object(
        'guilds', v_guilds,
        'live_sessions', v_sessions
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_guilds_and_arenas(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_guilds_and_arenas(INTEGER) TO authenticated, service_role;

-- 6.5 `admin_moderate_guild_or_arena` (force_finish_session returns sorted `leaderboard` for httpSend)
CREATE OR REPLACE FUNCTION public.admin_moderate_guild_or_arena(
    p_action TEXT,
    p_target_id UUID,
    p_reason TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_action TEXT := LOWER(BTRIM(COALESCE(p_action, '')));
    v_reason TEXT := COALESCE(NULLIF(LEFT(BTRIM(COALESCE(p_reason, '')), 200), ''), 'إجراء إشرافي: ' || v_action);
    v_affected INTEGER := 0;
    v_leaderboard JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF p_target_id IS NULL THEN
        RAISE EXCEPTION 'Target ID is required';
    END IF;

    IF v_action = 'delete_guild' THEN
        DELETE FROM public.guilds g WHERE g.id = p_target_id;
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF v_action = 'reset_single_guild_score' THEN
        UPDATE public.guilds g SET weekly_score = 0 WHERE g.id = p_target_id;
        GET DIAGNOSTICS v_affected = ROW_COUNT;
        UPDATE public.guild_members gm SET weekly_contribution = 0 WHERE gm.guild_id = p_target_id;

    ELSIF v_action = 'force_finish_session' THEN
        UPDATE public.live_quiz_sessions s
        SET status = 'finished'
        WHERE s.id = p_target_id;
        GET DIAGNOSTICS v_affected = ROW_COUNT;

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
        INTO v_leaderboard
        FROM public.live_quiz_participants p
        WHERE p.session_id = p_target_id;

    ELSIF v_action = 'delete_session' THEN
        DELETE FROM public.live_quiz_sessions s WHERE s.id = p_target_id;
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSE
        RAISE EXCEPTION 'Unsupported moderation action: %', v_action;
    END IF;

    PERFORM public._write_admin_audit_log(
        'guild_arena_moderation',
        'social',
        p_target_id::text,
        v_reason,
        jsonb_build_object('action', v_action, 'affected_count', v_affected)
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'action', v_action,
        'target_id', p_target_id,
        'affected_count', v_affected,
        'leaderboard', v_leaderboard
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_moderate_guild_or_arena(TEXT, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_moderate_guild_or_arena(TEXT, UUID, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 7. Seed New Feature Flags (`quick_phrases: true`, `live_arena_host_restricted: true`)
--    & Bump `config_version` so cached devices sync immediately
-- ------------------------------------------------------------------------------
UPDATE public.app_release_config cfg
SET feature_flags = COALESCE(cfg.feature_flags, '{}'::jsonb) || jsonb_build_object(
        'guilds_arenas', TRUE,
        'quick_phrases', TRUE,
        'live_arena_host_restricted', TRUE
    ),
    config_version = cfg.config_version + 1,
    updated_at = NOW()
WHERE cfg.platform = 'android';

-- ------------------------------------------------------------------------------
-- 8. Hardening: Ensure legacy SECURITY DEFINER RPCs have explicit search_path
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    v_fn RECORD;
BEGIN
    FOR v_fn IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef = TRUE
          AND p.proname IN (
              'cancel_private_room',
              'confirm_ready',
              'finish_match',
              'save_ghost_timeline',
              'submit_answer'
          )
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = public, auth', v_fn.sig);
    END LOOP;
END;
$$;
