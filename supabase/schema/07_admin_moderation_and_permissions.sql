-- ============================================================================
-- AUTO-GENERATED CANONICAL SCHEMA REFERENCE — DO NOT EDIT MANUALLY!
-- Domain: 07_admin_moderation_and_permissions.sql (الإشراف، حظر وصلاحيات اللاعبين، طاقم الإدارة، وسجل التدقيق)
-- Source: supabase/migrations/001..023 (23 migrations)
-- Generator: python tools/export_supabase_schema.py
-- Summary: 5 tables | 5 RLS policies | 3 indexes | 0 triggers | 20 functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLES & COLUMN/CONSTRAINT EVOLUTION
-- ----------------------------------------------------------------------------

-- Table: public.app_admins (origin: 015_app_control_and_messages.sql)
CREATE TABLE IF NOT EXISTS public.app_admins (
    email TEXT PRIMARY KEY CHECK (email = LOWER(BTRIM(email))),
    role TEXT NOT NULL DEFAULT 'owner',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.app_admins:
--   [015_app_control_and_messages.sql]
ALTER TABLE public.app_admins ENABLE ROW LEVEL SECURITY;

-- Table: public.admin_audit_logs (origin: 016_dynamic_cms_store_and_hardening.sql)
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
-- Effective ALTERs for public.admin_audit_logs:
--   [016_dynamic_cms_store_and_hardening.sql]
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Table: public.diwan_moderation (origin: 018_diwan_live_chat.sql)
CREATE TABLE IF NOT EXISTS public.diwan_moderation (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    muted_until TIMESTAMPTZ,
    reason TEXT,
    updated_by UUID,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.diwan_moderation:
--   [018_diwan_live_chat.sql]
ALTER TABLE public.diwan_moderation ENABLE ROW LEVEL SECURITY;

-- Table: public.diwan_reports (origin: 018_diwan_live_chat.sql)
CREATE TABLE IF NOT EXISTS public.diwan_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL DEFAULT 'مخالفة آداب الديوان',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (message_id, reporter_id)
);
-- Effective ALTERs for public.diwan_reports:
--   [018_diwan_live_chat.sql]
ALTER TABLE public.diwan_reports ENABLE ROW LEVEL SECURITY;

-- Table: public.player_permissions (origin: 021_admin_moderation_permissions_and_guards.sql)
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
-- Effective ALTERs for public.player_permissions:
--   [021_admin_moderation_permissions_and_guards.sql]
ALTER TABLE public.player_permissions ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 2. ACTIVE RLS POLICIES
-- ----------------------------------------------------------------------------

-- Policy: "Admins read audit logs" ON public.admin_audit_logs (latest: 016_dynamic_cms_store_and_hardening.sql)
CREATE POLICY "Admins read audit logs"
ON public.admin_audit_logs
FOR SELECT
TO authenticated
USING (public.check_is_admin());

-- Policy: "Admins manage diwan moderation" ON public.diwan_moderation (latest: 018_diwan_live_chat.sql)
CREATE POLICY "Admins manage diwan moderation"
    ON public.diwan_moderation FOR ALL
    TO authenticated
    USING (public.check_is_admin())
    WITH CHECK (public.check_is_admin());

-- Policy: "Reporters see own reports" ON public.diwan_reports (latest: 018_diwan_live_chat.sql)
CREATE POLICY "Reporters see own reports"
    ON public.diwan_reports FOR SELECT
    TO authenticated
    USING (auth.uid() = reporter_id OR public.check_is_admin());

-- Policy: "Admins manage player permissions" ON public.player_permissions (latest: 021_admin_moderation_permissions_and_guards.sql)
CREATE POLICY "Admins manage player permissions"
    ON public.player_permissions FOR ALL
    TO authenticated
    USING (public.check_is_admin())
    WITH CHECK (public.check_is_admin());

-- Policy: "Players read own permissions" ON public.player_permissions (latest: 021_admin_moderation_permissions_and_guards.sql)
CREATE POLICY "Players read own permissions"
    ON public.player_permissions FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id OR public.check_is_admin());

-- ----------------------------------------------------------------------------
-- 3. ACTIVE INDEXES
-- ----------------------------------------------------------------------------

-- Index: idx_admin_audit_logs_created ON public.admin_audit_logs (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created
    ON public.admin_audit_logs (created_at DESC);

-- Index: idx_admin_audit_logs_target ON public.admin_audit_logs (origin: 016_dynamic_cms_store_and_hardening.sql)
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target
    ON public.admin_audit_logs (target_type, target_id, created_at DESC);

-- Index: idx_player_permissions_banned ON public.player_permissions (origin: 021_admin_moderation_permissions_and_guards.sql)
CREATE INDEX IF NOT EXISTS idx_player_permissions_banned
    ON public.player_permissions (is_banned)
    WHERE is_banned = TRUE;

-- ----------------------------------------------------------------------------
-- 5. LATEST EFFECTIVE FUNCTIONS & RPCs
-- ----------------------------------------------------------------------------

-- Function: public._assert_player_allowed | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public._assert_player_allowed:
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public._assert_player_allowed(UUID, TEXT) FROM PUBLIC, anon, authenticated;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public._assert_player_allowed(UUID, TEXT) TO service_role;

-- Function: public._check_is_owner | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public._check_is_owner:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public._check_is_owner() FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public._check_is_owner() TO authenticated, service_role;

-- Function: public._current_actor_email | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public._current_actor_email:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public._current_actor_email() FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public._current_actor_email() TO authenticated, service_role;

-- Function: public._get_effective_player_permissions | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public._get_effective_player_permissions:
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public._get_effective_player_permissions(UUID) FROM PUBLIC, anon, authenticated;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public._get_effective_player_permissions(UUID) TO service_role;

-- Function: public._is_user_admin | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public._is_user_admin:
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public._is_user_admin(UUID) FROM PUBLIC, anon, authenticated;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public._is_user_admin(UUID) TO service_role;

-- Function: public._write_admin_audit_log | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public._write_admin_audit_log:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public._write_admin_audit_log(TEXT, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public._write_admin_audit_log(TEXT, TEXT, TEXT, TEXT, JSONB) TO service_role;

-- Function: public.admin_get_player_detail | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 2 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_get_player_detail:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_get_player_detail(UUID, TEXT) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_get_player_detail(UUID, TEXT) TO authenticated, service_role;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.admin_get_player_detail(UUID, TEXT) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.admin_get_player_detail(UUID, TEXT) TO authenticated, service_role;

-- Function: public.admin_grant_player_compensation | latest: 017_inbox_and_resource_health.sql | redefinitions: 2 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_grant_player_compensation:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_grant_player_compensation(UUID, INTEGER, INTEGER, INTEGER, TEXT) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_grant_player_compensation(UUID, INTEGER, INTEGER, INTEGER, TEXT) TO authenticated, service_role;
--   [017_inbox_and_resource_health.sql] REVOKE ALL ON FUNCTION public.admin_grant_player_compensation(UUID, INTEGER, INTEGER, INTEGER, TEXT) FROM PUBLIC;
--   [017_inbox_and_resource_health.sql] GRANT EXECUTE ON FUNCTION public.admin_grant_player_compensation(UUID, INTEGER, INTEGER, INTEGER, TEXT) TO authenticated, service_role;

-- Function: public.admin_list_admins | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_list_admins:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_list_admins() FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_list_admins() TO authenticated, service_role;

-- Function: public.admin_list_audit_logs | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_list_audit_logs:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_list_audit_logs(INTEGER) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_list_audit_logs(INTEGER) TO authenticated, service_role;

-- Function: public.admin_list_diwan_moderation_queue | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_list_diwan_moderation_queue:
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.admin_list_diwan_moderation_queue(INTEGER) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.admin_list_diwan_moderation_queue(INTEGER) TO authenticated, service_role;

-- Function: public.admin_list_ghosts | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_list_ghosts:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_list_ghosts(INTEGER) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_list_ghosts(INTEGER) TO authenticated, service_role;

-- Function: public.admin_list_guilds_and_arenas | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_list_guilds_and_arenas:
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.admin_list_guilds_and_arenas(INTEGER) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.admin_list_guilds_and_arenas(INTEGER) TO authenticated, service_role;

-- Function: public.admin_manage_admin | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_manage_admin:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_manage_admin(TEXT, TEXT, TEXT) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_manage_admin(TEXT, TEXT, TEXT) TO authenticated, service_role;

-- Function: public.admin_moderate_diwan | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 2 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_moderate_diwan:
--   [018_diwan_live_chat.sql] REVOKE ALL ON FUNCTION public.admin_moderate_diwan(TEXT, UUID, UUID, INTEGER, TEXT) FROM PUBLIC;
--   [018_diwan_live_chat.sql] GRANT EXECUTE ON FUNCTION public.admin_moderate_diwan(TEXT, UUID, UUID, INTEGER, TEXT) TO authenticated, service_role;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.admin_moderate_diwan(TEXT, UUID, UUID, INTEGER, TEXT) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.admin_moderate_diwan(TEXT, UUID, UUID, INTEGER, TEXT) TO authenticated, service_role;

-- Function: public.admin_moderate_guild_or_arena | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_moderate_guild_or_arena:
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.admin_moderate_guild_or_arena(TEXT, UUID, TEXT) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.admin_moderate_guild_or_arena(TEXT, UUID, TEXT) TO authenticated, service_role;

-- Function: public.admin_search_users | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_search_users(
    p_query TEXT DEFAULT '',
    p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_limit INTEGER := GREATEST(1, LEAST(20, COALESCE(p_limit, 20)));
    v_q TEXT := BTRIM(COALESCE(p_query, ''));
    v_escaped TEXT;
    v_rows JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    v_escaped := REPLACE(REPLACE(REPLACE(v_q, '\', '\\'), '%', '\%'), '_', '\_');

    WITH unified AS (
        SELECT
            pd.user_id,
            pd.player_code,
            COALESCE(NULLIF(pd.display_name, ''), lb.display_name, 'لاعب') AS display_name,
            COALESCE(pd.email, lb.email) AS email,
            GREATEST(COALESCE(pd.trophies, 1000), COALESCE(lb.trophies, 1000)) AS trophies,
            GREATEST(COALESCE(pd.player_level, 1), COALESCE(lb.player_level, 1)) AS player_level,
            GREATEST(COALESCE(pd.total_score, 0), COALESCE(lb.score, 0)) AS total_score,
            pd.platform,
            pd.app_version,
            pd.last_seen_at,
            (pd.user_id IS NULL) AS is_guest
        FROM public.player_directory pd
        LEFT JOIN public.leaderboard lb ON lb.user_id = pd.user_id

        UNION ALL

        SELECT
            lb.user_id,
            NULL::TEXT AS player_code,
            lb.display_name,
            lb.email,
            COALESCE(lb.trophies, 1000) AS trophies,
            COALESCE(lb.player_level, 1) AS player_level,
            COALESCE(lb.score, 0) AS total_score,
            'android'::TEXT AS platform,
            NULL::TEXT AS app_version,
            COALESCE(lb.updated_at, lb.created_at) AS last_seen_at,
            FALSE AS is_guest
        FROM public.leaderboard lb
        WHERE lb.user_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM public.player_directory pd2
              WHERE pd2.user_id = lb.user_id
          )
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(res)), '[]'::jsonb)
    INTO v_rows
    FROM (
        SELECT *
        FROM unified u
        WHERE v_q = ''
           OR u.display_name ILIKE ('%' || v_escaped || '%') ESCAPE '\'
           OR COALESCE(u.email, '') ILIKE ('%' || v_escaped || '%') ESCAPE '\'
           OR COALESCE(u.player_code, '') ILIKE ('%' || v_escaped || '%') ESCAPE '\'
        ORDER BY u.last_seen_at DESC NULLS LAST, u.total_score DESC
        LIMIT v_limit
    ) res;

    RETURN v_rows;
END;
$$;
-- Effective permission history for public.admin_search_users:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.admin_search_users(TEXT, INTEGER) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.admin_search_users(TEXT, INTEGER) TO authenticated, service_role;

-- Function: public.admin_toggle_ghost | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_toggle_ghost:
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_toggle_ghost(UUID, BOOLEAN) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_toggle_ghost(UUID, BOOLEAN) TO authenticated, service_role;

-- Function: public.admin_upsert_player_permissions | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.admin_upsert_player_permissions:
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.admin_upsert_player_permissions(UUID, BOOLEAN, INTEGER, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, TEXT) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.admin_upsert_player_permissions(UUID, BOOLEAN, INTEGER, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, TEXT) TO authenticated, service_role;

-- Function: public.check_is_admin | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID;
    v_email TEXT;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT u.email
    INTO v_email
    FROM auth.users u
    WHERE u.id = v_uid
    LIMIT 1;

    IF v_email IS NULL OR BTRIM(v_email) = '' THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.app_admins aa
        WHERE LOWER(aa.email) = LOWER(BTRIM(v_email))
    );
END;
$$;
-- Effective permission history for public.check_is_admin:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.check_is_admin() FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.check_is_admin() TO anon, authenticated, service_role;
