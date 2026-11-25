-- ============================================================================
-- AUTO-GENERATED CANONICAL SCHEMA REFERENCE — DO NOT EDIT MANUALLY!
-- Domain: 04_app_control_events_and_inbox.sql (التحكم السحابي، الإصدارات، الأحداث، الإعلانات، والبريد الملكي)
-- Source: supabase/migrations/001..024 (25 migrations)
-- Generator: python tools/export_supabase_schema.py
-- Summary: 4 tables | 0 RLS policies | 6 indexes | 0 triggers | 14 functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLES & COLUMN/CONSTRAINT EVOLUTION
-- ----------------------------------------------------------------------------

-- Table: public.admin_announcements (origin: 015_app_control_and_messages.sql)
CREATE TABLE IF NOT EXISTS public.admin_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'normal' CHECK (message_type IN ('normal', 'mandatory', 'admin', 'motivational')),
    target_scope TEXT NOT NULL DEFAULT 'all' CHECK (target_scope IN ('all', 'single_user')),
    target_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    target_player_code TEXT,
    cta_label TEXT,
    cta_route TEXT,
    is_dismissible BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    min_version_code INTEGER,
    max_version_code INTEGER,
    starts_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_announcement_target_valid CHECK (
        target_scope = 'all'
        OR target_user_id IS NOT NULL
        OR (target_player_code IS NOT NULL AND target_player_code ~ '^SAH-[A-Z0-9]{4,8}$')
    ),
    CONSTRAINT chk_announcement_version_bounds CHECK (
        min_version_code IS NULL OR max_version_code IS NULL OR min_version_code <= max_version_code
    )
);
-- Effective ALTERs for public.admin_announcements:
--   [015_app_control_and_messages.sql]
ALTER TABLE public.admin_announcements ADD COLUMN IF NOT EXISTS min_version_code INTEGER;
--   [015_app_control_and_messages.sql]
ALTER TABLE public.admin_announcements ADD COLUMN IF NOT EXISTS max_version_code INTEGER;
--   [015_app_control_and_messages.sql]
ALTER TABLE public.admin_announcements
            ADD CONSTRAINT chk_announcement_version_bounds
            CHECK (min_version_code IS NULL OR max_version_code IS NULL OR min_version_code <= max_version_code);
--   [015_app_control_and_messages.sql]
ALTER TABLE public.admin_announcements ENABLE ROW LEVEL SECURITY;

-- Table: public.app_dynamic_events (origin: 015_app_control_and_messages.sql)
CREATE TABLE IF NOT EXISTS public.app_dynamic_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    badge_text TEXT NOT NULL DEFAULT 'حدث نشط',
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL DEFAULT '',
    body TEXT NOT NULL DEFAULT '',
    cta_label TEXT NOT NULL DEFAULT 'اكتشف الآن',
    action_type TEXT NOT NULL DEFAULT 'open_event_screen' CHECK (action_type IN ('open_event_screen', 'navigate_route', 'open_url', 'none')),
    action_target TEXT NOT NULL DEFAULT '',
    theme_color_hex TEXT NOT NULL DEFAULT '#D4AF37',
    icon_name TEXT NOT NULL DEFAULT 'auto_awesome',
    priority INTEGER NOT NULL DEFAULT 100,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Effective ALTERs for public.app_dynamic_events:
--   [015_app_control_and_messages.sql]
ALTER TABLE public.app_dynamic_events ENABLE ROW LEVEL SECURITY;

-- Table: public.app_release_config (origin: 015_app_control_and_messages.sql)
CREATE TABLE IF NOT EXISTS public.app_release_config (
    platform TEXT PRIMARY KEY CHECK (platform IN ('android', 'ios', 'web', 'all')),
    min_version_code INTEGER NOT NULL DEFAULT 1 CHECK (min_version_code >= 1),
    latest_version_code INTEGER NOT NULL DEFAULT 18 CHECK (latest_version_code >= 1),
    latest_version_name TEXT NOT NULL DEFAULT '1.0.17',
    update_title TEXT NOT NULL DEFAULT 'تحديث جديد متاح',
    update_message TEXT NOT NULL DEFAULT 'أضفنا تحسينات ومحتوى جديداً لتجربة أفضل. حدّث التطبيق الآن.',
    update_url TEXT NOT NULL DEFAULT 'https://play.google.com/store/apps/details?id=com.ahfad.alsahaba.battle',
    maintenance_mode BOOLEAN NOT NULL DEFAULT FALSE,
    maintenance_title TEXT NOT NULL DEFAULT 'صيانة وتحسينات مؤقتة',
    maintenance_message TEXT NOT NULL DEFAULT 'نعمل الآن على ترقية الخوادم وإضافة أسئلة جديدة. نعود قريباً بإذن الله.',
    feature_flags JSONB NOT NULL DEFAULT '{"online_multiplayer": true, "ghost_matches": true, "private_rooms": true, "knights_store": true, "show_event_banner": true, "daily_challenges": true}'::jsonb,
    config_version BIGINT NOT NULL DEFAULT 1 CHECK (config_version >= 1),
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_release_version_bounds CHECK (min_version_code <= latest_version_code)
);
-- Effective ALTERs for public.app_release_config:
--   [015_app_control_and_messages.sql]
ALTER TABLE public.app_release_config ENABLE ROW LEVEL SECURITY;
--   [016_dynamic_cms_store_and_hardening.sql]
ALTER TABLE public.app_release_config
    ADD COLUMN IF NOT EXISTS cms_version BIGINT NOT NULL DEFAULT 1 CHECK (cms_version >= 1);

-- Table: public.user_announcement_receipts (origin: 015_app_control_and_messages.sql)
CREATE TABLE IF NOT EXISTS public.user_announcement_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    announcement_id UUID NOT NULL REFERENCES public.admin_announcements(id) ON DELETE CASCADE,
    recipient_key TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    player_code TEXT,
    seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (announcement_id, recipient_key)
);
-- Effective ALTERs for public.user_announcement_receipts:
--   [015_app_control_and_messages.sql]
ALTER TABLE public.user_announcement_receipts ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 3. ACTIVE INDEXES
-- ----------------------------------------------------------------------------

-- Index: idx_admin_announcements_active_scope ON public.admin_announcements (origin: 015_app_control_and_messages.sql)
CREATE INDEX IF NOT EXISTS idx_admin_announcements_active_scope
    ON public.admin_announcements (is_active, target_scope, created_at DESC)
    WHERE is_active = TRUE;

-- Index: idx_admin_announcements_target_code ON public.admin_announcements (origin: 015_app_control_and_messages.sql)
CREATE INDEX IF NOT EXISTS idx_admin_announcements_target_code
    ON public.admin_announcements (target_player_code)
    WHERE target_player_code IS NOT NULL;

-- Index: idx_admin_announcements_target_uid ON public.admin_announcements (origin: 015_app_control_and_messages.sql)
CREATE INDEX IF NOT EXISTS idx_admin_announcements_target_uid
    ON public.admin_announcements (target_user_id)
    WHERE target_user_id IS NOT NULL;

-- Index: idx_app_dynamic_events_active ON public.app_dynamic_events (origin: 015_app_control_and_messages.sql)
CREATE INDEX IF NOT EXISTS idx_app_dynamic_events_active
    ON public.app_dynamic_events (is_active, priority DESC, updated_at DESC)
    WHERE is_active = TRUE;

-- Index: idx_user_announcement_receipts_code ON public.user_announcement_receipts (origin: 015_app_control_and_messages.sql)
CREATE INDEX IF NOT EXISTS idx_user_announcement_receipts_code
    ON public.user_announcement_receipts (player_code, announcement_id)
    WHERE player_code IS NOT NULL;

-- Index: idx_user_announcement_receipts_uid ON public.user_announcement_receipts (origin: 015_app_control_and_messages.sql)
CREATE INDEX IF NOT EXISTS idx_user_announcement_receipts_uid
    ON public.user_announcement_receipts (user_id, announcement_id)
    WHERE user_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 5. LATEST EFFECTIVE FUNCTIONS & RPCs
-- ----------------------------------------------------------------------------

-- Function: public._bump_app_config_version | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public._bump_app_config_version(
    p_platform TEXT DEFAULT 'android',
    p_admin_id UUID DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_platform TEXT := COALESCE(NULLIF(LOWER(BTRIM(p_platform)), ''), 'android');
    v_new_version BIGINT;
BEGIN
    INSERT INTO public.app_release_config (platform, updated_by, config_version)
    VALUES (v_platform, p_admin_id, 1)
    ON CONFLICT (platform) DO NOTHING;

    UPDATE public.app_release_config cfg
    SET config_version = cfg.config_version + 1,
        updated_at = NOW(),
        updated_by = COALESCE(p_admin_id, cfg.updated_by)
    WHERE cfg.platform = v_platform
    RETURNING cfg.config_version INTO v_new_version;

    RETURN COALESCE(v_new_version, 1);
END;
$$;
-- Effective permission history for public._bump_app_config_version:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public._bump_app_config_version(TEXT, UUID) FROM PUBLIC, anon, authenticated;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public._bump_app_config_version(TEXT, UUID) TO service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public._bump_app_config_version FROM PUBLIC, anon; -- via DO block

-- Function: public.acknowledge_announcement | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.acknowledge_announcement(
    p_announcement_id UUID,
    p_player_code TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_raw_code TEXT := UPPER(BTRIM(COALESCE(p_player_code, '')));
    v_valid_code TEXT := NULL;
BEGIN
    IF p_announcement_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF v_raw_code ~ '^SAH-[A-Z0-9]{4,8}$' AND LENGTH(v_raw_code) BETWEEN 8 AND 12 THEN
        v_valid_code := v_raw_code;
    END IF;

    IF v_uid IS NULL AND v_valid_code IS NULL THEN
        RETURN FALSE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.admin_announcements ann
        WHERE ann.id = p_announcement_id
    ) THEN
        RETURN FALSE;
    END IF;

    IF v_uid IS NOT NULL THEN
        INSERT INTO public.user_announcement_receipts (
            announcement_id, recipient_key, user_id, player_code, seen_at, acknowledged_at
        )
        VALUES (
            p_announcement_id, 'uid:' || v_uid::text, v_uid, v_valid_code, NOW(), NOW()
        )
        ON CONFLICT (announcement_id, recipient_key) DO UPDATE
        SET acknowledged_at = NOW(),
            player_code = COALESCE(EXCLUDED.player_code, user_announcement_receipts.player_code);
    END IF;

    IF v_valid_code IS NOT NULL THEN
        INSERT INTO public.user_announcement_receipts (
            announcement_id, recipient_key, user_id, player_code, seen_at, acknowledged_at
        )
        VALUES (
            p_announcement_id, 'code:' || v_valid_code, v_uid, v_valid_code, NOW(), NOW()
        )
        ON CONFLICT (announcement_id, recipient_key) DO UPDATE
        SET acknowledged_at = NOW(),
            user_id = COALESCE(EXCLUDED.user_id, user_announcement_receipts.user_id);
    END IF;

    RETURN TRUE;
END;
$$;
-- Effective permission history for public.acknowledge_announcement:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.acknowledge_announcement(UUID, TEXT) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.acknowledge_announcement(UUID, TEXT) TO anon, authenticated, service_role;

-- Function: public.admin_create_announcement | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_create_announcement(
    p_title TEXT,
    p_body TEXT,
    p_message_type TEXT DEFAULT 'normal',
    p_target_scope TEXT DEFAULT 'all',
    p_target_user_id UUID DEFAULT NULL,
    p_target_player_code TEXT DEFAULT NULL,
    p_cta_label TEXT DEFAULT NULL,
    p_cta_route TEXT DEFAULT NULL,
    p_is_dismissible BOOLEAN DEFAULT TRUE,
    p_expires_at TIMESTAMPTZ DEFAULT NULL,
    p_min_version_code INTEGER DEFAULT NULL,
    p_max_version_code INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_title TEXT := BTRIM(COALESCE(p_title, ''));
    v_body TEXT := BTRIM(COALESCE(p_body, ''));
    v_type TEXT := LOWER(BTRIM(COALESCE(p_message_type, 'normal')));
    v_scope TEXT := LOWER(BTRIM(COALESCE(p_target_scope, 'all')));
    v_code TEXT := NULLIF(UPPER(BTRIM(COALESCE(p_target_player_code, ''))), '');
    v_dismissible BOOLEAN := COALESCE(p_is_dismissible, TRUE);
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_title = '' OR v_body = '' THEN
        RAISE EXCEPTION 'Announcement title and body cannot be empty';
    END IF;

    IF p_min_version_code IS NOT NULL
       AND p_max_version_code IS NOT NULL
       AND p_min_version_code > p_max_version_code THEN
        RAISE EXCEPTION 'min_version_code cannot exceed max_version_code';
    END IF;

    IF v_type NOT IN ('normal', 'mandatory', 'admin', 'motivational') THEN
        v_type := 'normal';
    END IF;

    IF v_type = 'mandatory' THEN
        v_dismissible := FALSE;
    END IF;

    IF v_scope NOT IN ('all', 'single_user') THEN
        v_scope := 'all';
    END IF;

    IF v_scope = 'single_user' THEN
        IF v_code IS NOT NULL AND (v_code !~ '^SAH-[A-Z0-9]{4,8}$' OR LENGTH(v_code) NOT BETWEEN 8 AND 12) THEN
            RAISE EXCEPTION 'Invalid target_player_code format';
        END IF;

        IF p_target_user_id IS NULL AND v_code IS NULL THEN
            RAISE EXCEPTION 'Single-user announcement requires target_user_id or valid target_player_code';
        END IF;
    ELSE
        v_code := NULL;
    END IF;

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
        min_version_code,
        max_version_code,
        expires_at,
        created_by,
        updated_at
    )
    VALUES (
        v_title,
        v_body,
        v_type,
        v_scope,
        CASE WHEN v_scope = 'single_user' THEN p_target_user_id ELSE NULL END,
        CASE WHEN v_scope = 'single_user' THEN v_code ELSE NULL END,
        NULLIF(BTRIM(COALESCE(p_cta_label, '')), ''),
        NULLIF(BTRIM(COALESCE(p_cta_route, '')), ''),
        v_dismissible,
        TRUE,
        p_min_version_code,
        p_max_version_code,
        p_expires_at,
        v_uid,
        NOW()
    )
    RETURNING * INTO v_row;

    -- Broadcast updates bump config_version so clients fetch immediately after TTL;
    -- single_user messages remain zero-cost for non-targeted players while still
    -- fetched for the recipient even if config_version is unchanged.
    IF v_scope = 'all' THEN
        PERFORM public._bump_app_config_version('android', v_uid);
    END IF;

    RETURN to_jsonb(v_row);
END;
$$;
-- Effective permission history for public.admin_create_announcement:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.admin_create_announcement(TEXT, TEXT, TEXT, TEXT, UUID, TEXT, TEXT, TEXT, BOOLEAN, TIMESTAMPTZ, INTEGER, INTEGER) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.admin_create_announcement(TEXT, TEXT, TEXT, TEXT, UUID, TEXT, TEXT, TEXT, BOOLEAN, TIMESTAMPTZ, INTEGER, INTEGER) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_create_announcement FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_delete_dynamic_event | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_delete_dynamic_event(p_event_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    DELETE FROM public.app_dynamic_events ev
    WHERE ev.id = p_event_id;

    IF FOUND THEN
        PERFORM public._bump_app_config_version('android', v_uid);
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;
-- Effective permission history for public.admin_delete_dynamic_event:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.admin_delete_dynamic_event(UUID) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.admin_delete_dynamic_event(UUID) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_delete_dynamic_event FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_get_overview | latest: 016_dynamic_cms_store_and_hardening.sql | redefinitions: 2 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_get_overview()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_total_accounts INTEGER := 0;
    v_directory_players INTEGER := 0;
    v_guest_players INTEGER := 0;
    v_active_24h INTEGER := 0;
    v_active_events INTEGER := 0;
    v_active_announcements INTEGER := 0;
    v_store_items_count INTEGER := 0;
    v_library_items_count INTEGER := 0;
    v_quiz_questions_count INTEGER := 0;
    v_total_ghosts INTEGER := 0;
    v_active_ghosts INTEGER := 0;
    v_human_ghosts INTEGER := 0;
    v_version_breakdown JSONB := '[]'::jsonb;
    v_release_config JSONB := '{}'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COUNT(*) INTO v_total_accounts FROM public.leaderboard lb;
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE pd.user_id IS NULL),
        COUNT(*) FILTER (WHERE pd.last_seen_at >= NOW() - INTERVAL '24 hours')
    INTO v_directory_players, v_guest_players, v_active_24h
    FROM public.player_directory pd;

    SELECT COALESCE(jsonb_agg(to_jsonb(vb) ORDER BY vb.version_code DESC), '[]'::jsonb)
    INTO v_version_breakdown
    FROM (
        SELECT
            pd.version_code,
            MAX(pd.app_version) AS app_version,
            COUNT(*) AS players_count
        FROM public.player_directory pd
        GROUP BY pd.version_code
    ) vb;

    SELECT COUNT(*)
    INTO v_active_events
    FROM public.app_dynamic_events ev
    WHERE ev.is_active = TRUE
      AND (ev.ends_at IS NULL OR ev.ends_at > NOW());

    SELECT COUNT(*)
    INTO v_active_announcements
    FROM public.admin_announcements ann
    WHERE ann.is_active = TRUE
      AND (ann.expires_at IS NULL OR ann.expires_at > NOW());

    SELECT COUNT(*) INTO v_store_items_count FROM public.store_items s;
    SELECT COUNT(*) INTO v_library_items_count FROM public.library_items li;
    SELECT COUNT(*) INTO v_quiz_questions_count FROM public.quiz_questions qq;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE gr.is_active = TRUE),
        COUNT(*) FILTER (WHERE gr.user_id IS NOT NULL)
    INTO v_total_ghosts, v_active_ghosts, v_human_ghosts
    FROM public.ghost_recordings gr;

    SELECT to_jsonb(cfg)
    INTO v_release_config
    FROM public.app_release_config cfg
    WHERE cfg.platform = 'android'
    LIMIT 1;

    RETURN jsonb_build_object(
        'total_accounts', v_total_accounts,
        'directory_players', v_directory_players,
        'guest_players', v_guest_players,
        'active_24h', v_active_24h,
        'active_events', v_active_events,
        'active_announcements', v_active_announcements,
        'cms_version', COALESCE((v_release_config->>'cms_version')::BIGINT, 1),
        'store_items_count', v_store_items_count,
        'library_items_count', v_library_items_count,
        'quiz_questions_count', v_quiz_questions_count,
        'total_ghosts', v_total_ghosts,
        'active_ghosts', v_active_ghosts,
        'human_ghosts', v_human_ghosts,
        'version_breakdown', v_version_breakdown,
        'release_config', COALESCE(v_release_config, '{}'::jsonb)
    );
END;
$$;
-- Effective permission history for public.admin_get_overview:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.admin_get_overview() FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.admin_get_overview() TO authenticated, service_role;
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.admin_get_overview() FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.admin_get_overview() TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_get_overview FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_list_announcements | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_list_announcements(
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
    v_limit INTEGER := GREATEST(1, LEAST(100, COALESCE(p_limit, 50)));
    v_rows JSONB := '[]'::jsonb;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    SELECT COALESCE(jsonb_agg(t.payload), '[]'::jsonb)
    INTO v_rows
    FROM (
        SELECT
            to_jsonb(ann) || jsonb_build_object(
                'receipt_count', (
                    SELECT COUNT(DISTINCT rec.recipient_key)
                    FROM public.user_announcement_receipts rec
                    WHERE rec.announcement_id = ann.id
                )
            ) AS payload
        FROM public.admin_announcements ann
        ORDER BY ann.is_active DESC, ann.created_at DESC
        LIMIT v_limit
    ) t;

    RETURN v_rows;
END;
$$;
-- Effective permission history for public.admin_list_announcements:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.admin_list_announcements(INTEGER) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.admin_list_announcements(INTEGER) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_list_announcements FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_list_dynamic_events | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_list_dynamic_events()
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

    SELECT COALESCE(
        jsonb_agg(to_jsonb(ev) ORDER BY ev.is_active DESC, ev.priority DESC, ev.updated_at DESC),
        '[]'::jsonb
    )
    INTO v_rows
    FROM public.app_dynamic_events ev;

    RETURN v_rows;
END;
$$;
-- Effective permission history for public.admin_list_dynamic_events:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.admin_list_dynamic_events() FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.admin_list_dynamic_events() TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_list_dynamic_events FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_set_announcement_active | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_set_announcement_active(
    p_announcement_id UUID,
    p_is_active BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_scope TEXT;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    UPDATE public.admin_announcements ann
    SET is_active = COALESCE(p_is_active, FALSE),
        updated_at = NOW()
    WHERE ann.id = p_announcement_id
    RETURNING ann.target_scope INTO v_scope;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF v_scope = 'all' THEN
        PERFORM public._bump_app_config_version('android', v_uid);
    END IF;

    RETURN TRUE;
END;
$$;
-- Effective permission history for public.admin_set_announcement_active:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.admin_set_announcement_active(UUID, BOOLEAN) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.admin_set_announcement_active(UUID, BOOLEAN) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_set_announcement_active FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_toggle_dynamic_event | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_toggle_dynamic_event(
    p_event_id UUID,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    UPDATE public.app_dynamic_events ev
    SET is_active = COALESCE(p_is_active, FALSE),
        updated_at = NOW()
    WHERE ev.id = p_event_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dynamic event not found';
    END IF;

    PERFORM public._bump_app_config_version('android', v_uid);
    RETURN to_jsonb(v_row);
END;
$$;
-- Effective permission history for public.admin_toggle_dynamic_event:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.admin_toggle_dynamic_event(UUID, BOOLEAN) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.admin_toggle_dynamic_event(UUID, BOOLEAN) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_toggle_dynamic_event FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_upsert_dynamic_event | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_upsert_dynamic_event(
    p_id UUID DEFAULT NULL,
    p_badge_text TEXT DEFAULT 'حدث نشط',
    p_title TEXT DEFAULT '',
    p_subtitle TEXT DEFAULT '',
    p_body TEXT DEFAULT '',
    p_cta_label TEXT DEFAULT 'اكتشف الآن',
    p_action_type TEXT DEFAULT 'open_event_screen',
    p_action_target TEXT DEFAULT '',
    p_theme_color_hex TEXT DEFAULT '#D4AF37',
    p_icon_name TEXT DEFAULT 'auto_awesome',
    p_priority INTEGER DEFAULT 100,
    p_is_active BOOLEAN DEFAULT TRUE,
    p_starts_at TIMESTAMPTZ DEFAULT NULL,
    p_ends_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_title TEXT := BTRIM(COALESCE(p_title, ''));
    v_action TEXT := LOWER(BTRIM(COALESCE(p_action_type, 'open_event_screen')));
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    IF v_title = '' THEN
        RAISE EXCEPTION 'Event title cannot be empty';
    END IF;

    IF v_action NOT IN ('open_event_screen', 'navigate_route', 'open_url', 'none') THEN
        v_action := 'open_event_screen';
    END IF;

    IF p_id IS NOT NULL THEN
        UPDATE public.app_dynamic_events ev
        SET badge_text = COALESCE(NULLIF(BTRIM(p_badge_text), ''), 'حدث نشط'),
            title = v_title,
            subtitle = COALESCE(BTRIM(p_subtitle), ''),
            body = COALESCE(BTRIM(p_body), ''),
            cta_label = COALESCE(NULLIF(BTRIM(p_cta_label), ''), 'اكتشف الآن'),
            action_type = v_action,
            action_target = COALESCE(BTRIM(p_action_target), ''),
            theme_color_hex = COALESCE(NULLIF(BTRIM(p_theme_color_hex), ''), '#D4AF37'),
            icon_name = COALESCE(NULLIF(BTRIM(p_icon_name), ''), 'auto_awesome'),
            priority = COALESCE(p_priority, 100),
            is_active = COALESCE(p_is_active, TRUE),
            starts_at = p_starts_at,
            ends_at = p_ends_at,
            updated_at = NOW()
        WHERE ev.id = p_id
        RETURNING * INTO v_row;
    END IF;

    IF NOT FOUND OR p_id IS NULL THEN
        INSERT INTO public.app_dynamic_events (
            id, badge_text, title, subtitle, body, cta_label,
            action_type, action_target, theme_color_hex, icon_name,
            priority, is_active, starts_at, ends_at, created_by, updated_at
        )
        VALUES (
            COALESCE(p_id, gen_random_uuid()),
            COALESCE(NULLIF(BTRIM(p_badge_text), ''), 'حدث نشط'),
            v_title,
            COALESCE(BTRIM(p_subtitle), ''),
            COALESCE(BTRIM(p_body), ''),
            COALESCE(NULLIF(BTRIM(p_cta_label), ''), 'اكتشف الآن'),
            v_action,
            COALESCE(BTRIM(p_action_target), ''),
            COALESCE(NULLIF(BTRIM(p_theme_color_hex), ''), '#D4AF37'),
            COALESCE(NULLIF(BTRIM(p_icon_name), ''), 'auto_awesome'),
            COALESCE(p_priority, 100),
            COALESCE(p_is_active, TRUE),
            p_starts_at,
            p_ends_at,
            v_uid,
            NOW()
        )
        RETURNING * INTO v_row;
    END IF;

    PERFORM public._bump_app_config_version('android', v_uid);
    RETURN to_jsonb(v_row);
END;
$$;
-- Effective permission history for public.admin_upsert_dynamic_event:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.admin_upsert_dynamic_event(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.admin_upsert_dynamic_event(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_upsert_dynamic_event FROM PUBLIC, anon; -- via DO block

-- Function: public.admin_upsert_release_config | latest: 015_app_control_and_messages.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.admin_upsert_release_config(
    p_platform TEXT DEFAULT 'android',
    p_min_version_code INTEGER DEFAULT 1,
    p_latest_version_code INTEGER DEFAULT 18,
    p_latest_version_name TEXT DEFAULT '1.0.17',
    p_update_title TEXT DEFAULT 'تحديث جديد متاح',
    p_update_message TEXT DEFAULT '',
    p_update_url TEXT DEFAULT 'https://play.google.com/store/apps/details?id=com.ahfad.alsahaba.battle',
    p_maintenance_mode BOOLEAN DEFAULT FALSE,
    p_maintenance_title TEXT DEFAULT 'صيانة وتحسينات مؤقتة',
    p_maintenance_message TEXT DEFAULT '',
    p_feature_flags JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
    v_uid UUID := auth.uid();
    v_platform TEXT := COALESCE(NULLIF(LOWER(BTRIM(p_platform)), ''), 'android');
    v_min_code INTEGER := GREATEST(1, COALESCE(p_min_version_code, 1));
    v_latest_code INTEGER := GREATEST(v_min_code, COALESCE(p_latest_version_code, 18));
    v_row RECORD;
BEGIN
    IF NOT public.check_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: admin access required';
    END IF;

    INSERT INTO public.app_release_config (
        platform,
        min_version_code,
        latest_version_code,
        latest_version_name,
        update_title,
        update_message,
        update_url,
        maintenance_mode,
        maintenance_title,
        maintenance_message,
        feature_flags,
        config_version,
        updated_by,
        updated_at
    )
    VALUES (
        v_platform,
        v_min_code,
        v_latest_code,
        COALESCE(NULLIF(BTRIM(p_latest_version_name), ''), '1.0.17'),
        COALESCE(NULLIF(BTRIM(p_update_title), ''), 'تحديث جديد متاح'),
        COALESCE(BTRIM(p_update_message), ''),
        COALESCE(NULLIF(BTRIM(p_update_url), ''), 'https://play.google.com/store/apps/details?id=com.ahfad.alsahaba.battle'),
        COALESCE(p_maintenance_mode, FALSE),
        COALESCE(NULLIF(BTRIM(p_maintenance_title), ''), 'صيانة وتحسينات مؤقتة'),
        COALESCE(BTRIM(p_maintenance_message), ''),
        COALESCE(p_feature_flags, '{"online_multiplayer": true, "ghost_matches": true, "private_rooms": true, "knights_store": true, "show_event_banner": true, "daily_challenges": true}'::jsonb),
        1,
        v_uid,
        NOW()
    )
    ON CONFLICT (platform) DO UPDATE
    SET min_version_code = EXCLUDED.min_version_code,
        latest_version_code = EXCLUDED.latest_version_code,
        latest_version_name = EXCLUDED.latest_version_name,
        update_title = EXCLUDED.update_title,
        update_message = EXCLUDED.update_message,
        update_url = EXCLUDED.update_url,
        maintenance_mode = EXCLUDED.maintenance_mode,
        maintenance_title = EXCLUDED.maintenance_title,
        maintenance_message = EXCLUDED.maintenance_message,
        feature_flags = COALESCE(p_feature_flags, app_release_config.feature_flags),
        config_version = app_release_config.config_version + 1,
        updated_by = v_uid,
        updated_at = NOW()
    RETURNING * INTO v_row;

    RETURN to_jsonb(v_row);
END;
$$;
-- Effective permission history for public.admin_upsert_release_config:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.admin_upsert_release_config(TEXT, INTEGER, INTEGER, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT, JSONB) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.admin_upsert_release_config(TEXT, INTEGER, INTEGER, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT, JSONB) TO authenticated, service_role;
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.admin_upsert_release_config FROM PUBLIC, anon; -- via DO block

-- Function: public.get_app_control_state | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 3 | security_definer: True | search_path: True
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
-- Effective permission history for public.get_app_control_state:
--   [015_app_control_and_messages.sql] REVOKE ALL ON FUNCTION public.get_app_control_state(TEXT, INTEGER, BIGINT, TEXT) FROM PUBLIC;
--   [015_app_control_and_messages.sql] GRANT EXECUTE ON FUNCTION public.get_app_control_state(TEXT, INTEGER, BIGINT, TEXT) TO anon, authenticated, service_role;
--   [016_dynamic_cms_store_and_hardening.sql] REVOKE ALL ON FUNCTION public.get_app_control_state(TEXT, INTEGER, BIGINT, TEXT) FROM PUBLIC;
--   [016_dynamic_cms_store_and_hardening.sql] GRANT EXECUTE ON FUNCTION public.get_app_control_state(TEXT, INTEGER, BIGINT, TEXT) TO anon, authenticated, service_role;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.get_app_control_state(TEXT, INTEGER, BIGINT, TEXT) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.get_app_control_state(TEXT, INTEGER, BIGINT, TEXT) TO anon, authenticated, service_role;

-- Function: public.get_player_inbox | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 2 | security_definer: True | search_path: True
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
-- Effective permission history for public.get_player_inbox:
--   [017_inbox_and_resource_health.sql] REVOKE ALL ON FUNCTION public.get_player_inbox(TEXT, INTEGER) FROM PUBLIC;
--   [017_inbox_and_resource_health.sql] GRANT EXECUTE ON FUNCTION public.get_player_inbox(TEXT, INTEGER) TO anon, authenticated, service_role;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.get_player_inbox(TEXT, INTEGER) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.get_player_inbox(TEXT, INTEGER) TO anon, authenticated, service_role;

-- Function: public.mark_all_inbox_read | latest: 017_inbox_and_resource_health.sql | redefinitions: 1 | security_definer: True | search_path: True
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
-- Effective permission history for public.mark_all_inbox_read:
--   [017_inbox_and_resource_health.sql] REVOKE ALL ON FUNCTION public.mark_all_inbox_read(TEXT) FROM PUBLIC;
--   [017_inbox_and_resource_health.sql] GRANT EXECUTE ON FUNCTION public.mark_all_inbox_read(TEXT) TO anon, authenticated, service_role;
