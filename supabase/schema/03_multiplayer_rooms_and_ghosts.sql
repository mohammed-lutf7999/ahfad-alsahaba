-- ============================================================================
-- AUTO-GENERATED CANONICAL SCHEMA REFERENCE — DO NOT EDIT MANUALLY!
-- Domain: 03_multiplayer_rooms_and_ghosts.sql (المطابقة التنافسية، المباريات، الغرف الخاصة، وأشباح الصحابة)
-- Source: supabase/migrations/001..024 (26 migrations)
-- Generator: python tools/export_supabase_schema.py
-- Summary: 4 tables | 6 RLS policies | 8 indexes | 0 triggers | 11 functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLES & COLUMN/CONSTRAINT EVOLUTION
-- ----------------------------------------------------------------------------

-- Table: public.match_participants (origin: 003_multiplayer_schema.sql)
create table match_participants (
  id uuid default gen_random_uuid() primary key,
  match_id uuid references matches on delete cascade not null,
  user_id uuid references auth.users not null,
  current_score int default 0,
  current_question_index int default 0,
  finished_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(match_id, user_id)
);
-- Effective ALTERs for public.match_participants:
--   [003_multiplayer_schema.sql]
alter table match_participants enable row level security;
--   [004_multiplayer_fix.sql]
ALTER TABLE match_participants ADD COLUMN IF NOT EXISTS is_ready BOOLEAN DEFAULT FALSE;
--   [004_multiplayer_fix.sql]
ALTER TABLE match_participants ADD COLUMN IF NOT EXISTS ready_at TIMESTAMPTZ;
--   [008_multiplayer_rock_solid_fix.sql]
ALTER TABLE public.match_participants REPLICA IDENTITY FULL;

-- Table: public.matches (origin: 003_multiplayer_schema.sql)
create table matches (
  id uuid default gen_random_uuid() primary key,
  player1_id uuid references auth.users not null,
  player2_id uuid references auth.users not null,
  status text check (status in ('waiting', 'active', 'finished')) default 'active',
  winner_id uuid references auth.users,
  seed bigint not null, -- Random seed for deterministic question selection
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
-- Effective ALTERs for public.matches:
--   [003_multiplayer_schema.sql]
alter table matches enable row level security;
--   [004_multiplayer_fix.sql]
ALTER TABLE matches DROP CONSTRAINT IF EXISTS matches_status_check;
--   [004_multiplayer_fix.sql]
ALTER TABLE matches ADD CONSTRAINT matches_status_check 
CHECK (status IN ('waiting', 'matched', 'ready', 'playing', 'finished'));
--   [004_multiplayer_fix.sql]
ALTER TABLE matches ADD COLUMN IF NOT EXISTS question_ids TEXT[];
--   [004_multiplayer_fix.sql]
ALTER TABLE matches ADD COLUMN IF NOT EXISTS current_question INT DEFAULT 0;
--   [004_multiplayer_fix.sql]
ALTER TABLE matches ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;
--   [006_add_seed_column.sql]
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS seed INT DEFAULT FLOOR(RANDOM() * 1000000);
--   [006_add_seed_column.sql]
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS questions JSONB;
--   [007_reset_queue_and_fix.sql]
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS questions JSONB DEFAULT '[]'::jsonb;
--   [008_multiplayer_rock_solid_fix.sql]
ALTER TABLE public.matches REPLICA IDENTITY FULL;
--   [010_instant_rematch_system.sql]
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS parent_match_id UUID REFERENCES public.matches(id),
ADD COLUMN IF NOT EXISTS rematch_count INTEGER DEFAULT 0;
--   [011_private_rooms_system.sql]
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS room_code VARCHAR(6),
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
--   [011_private_rooms_system.sql]
ALTER TABLE public.matches ALTER COLUMN player2_id DROP NOT NULL;
--   [013_ghost_replay_engine.sql]
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS is_ghost_match BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_friendly BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS ghost_score INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS source_ghost_recording_id UUID REFERENCES public.ghost_recordings(id);

-- Table: public.matchmaking_queue (origin: 003_multiplayer_schema.sql)
create table matchmaking_queue (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null unique,
  app_version text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  score int default 0
);
-- Effective ALTERs for public.matchmaking_queue:
--   [003_multiplayer_schema.sql]
alter table matchmaking_queue enable row level security;
--   [006_add_seed_column.sql]
ALTER TABLE public.matchmaking_queue ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
--   [008_multiplayer_rock_solid_fix.sql]
ALTER TABLE public.matchmaking_queue REPLICA IDENTITY FULL;
--   [012_dynamic_trophy_matchmaking.sql]
ALTER TABLE public.matchmaking_queue 
ADD COLUMN IF NOT EXISTS trophies INTEGER DEFAULT 1000;

-- Table: public.ghost_recordings (origin: 013_ghost_replay_engine.sql)
CREATE TABLE IF NOT EXISTS public.ghost_recordings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_match_id UUID,
  user_id UUID,
  display_name TEXT NOT NULL DEFAULT 'فارس الأندلس',
  avatar_index INTEGER NOT NULL DEFAULT 0,
  equipped_frame TEXT NOT NULL DEFAULT 'frame_wood',
  player_level INTEGER NOT NULL DEFAULT 5,
  trophies INTEGER NOT NULL DEFAULT 1000,
  seed BIGINT NOT NULL,
  question_ids TEXT[] NOT NULL,
  timeline JSONB NOT NULL,
  total_score INTEGER NOT NULL DEFAULT 0,
  use_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
-- Effective ALTERs for public.ghost_recordings:
--   [013_ghost_replay_engine.sql]
ALTER TABLE public.ghost_recordings ENABLE ROW LEVEL SECURITY;
--   [014_ghost_world_class_hardening.sql]
ALTER TABLE public.ghost_recordings
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- ----------------------------------------------------------------------------
-- 2. ACTIVE RLS POLICIES
-- ----------------------------------------------------------------------------

-- Policy: "System creates participants" ON public.match_participants (latest: 004_multiplayer_fix.sql)
CREATE POLICY "System creates participants" ON match_participants FOR INSERT WITH CHECK (true);

-- Policy: "Users can see participants in their match" ON public.match_participants (latest: 003_multiplayer_schema.sql)
create policy "Users can see participants in their match" on match_participants for select using (
  exists (
    select 1 from matches m 
    where m.id = match_participants.match_id 
    and (m.player1_id = auth.uid() or m.player2_id = auth.uid())
  )
);

-- Policy: "Users can update their own progress" ON public.match_participants (latest: 003_multiplayer_schema.sql)
create policy "Users can update their own progress" on match_participants for update using (auth.uid() = user_id);

-- Policy: "Users can see their matches" ON public.matches (latest: 003_multiplayer_schema.sql)
create policy "Users can see their matches" on matches for select using (auth.uid() = player1_id or auth.uid() = player2_id);

-- Policy: "Users can delete themselves" ON public.matchmaking_queue (latest: 003_multiplayer_schema.sql)
create policy "Users can delete themselves" on matchmaking_queue for delete using (auth.uid() = user_id);

-- Policy: "Users can insert themselves" ON public.matchmaking_queue (latest: 003_multiplayer_schema.sql)
create policy "Users can insert themselves" on matchmaking_queue for insert with check (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 3. ACTIVE INDEXES
-- ----------------------------------------------------------------------------

-- Index: idx_matches_ghost ON public.matches (origin: 013_ghost_replay_engine.sql)
CREATE INDEX IF NOT EXISTS idx_matches_ghost 
ON public.matches(is_ghost_match) 
WHERE is_ghost_match = TRUE;

-- Index: idx_matches_parent_rematch ON public.matches (origin: 010_instant_rematch_system.sql)
CREATE INDEX IF NOT EXISTS idx_matches_parent_rematch 
ON public.matches(parent_match_id);

-- Index: idx_matches_room_code ON public.matches (origin: 011_private_rooms_system.sql)
CREATE INDEX IF NOT EXISTS idx_matches_room_code 
ON public.matches(room_code) 
WHERE room_code IS NOT NULL;

-- Index: idx_queue_trophies_created ON public.matchmaking_queue (origin: 012_dynamic_trophy_matchmaking.sql)
CREATE INDEX IF NOT EXISTS idx_queue_trophies_created 
ON public.matchmaking_queue(trophies, created_at);

-- Index: idx_ghost_active_trophies ON public.ghost_recordings (origin: 014_ghost_world_class_hardening.sql)
CREATE INDEX IF NOT EXISTS idx_ghost_active_trophies
  ON public.ghost_recordings (is_active, trophies, created_at DESC);

-- Index: idx_ghost_trophies ON public.ghost_recordings (origin: 013_ghost_replay_engine.sql)
CREATE INDEX IF NOT EXISTS idx_ghost_trophies 
ON public.ghost_recordings(trophies, created_at);

-- Index: idx_ghost_unique_match_user ON public.ghost_recordings (origin: 013_ghost_replay_engine.sql)
CREATE UNIQUE INDEX IF NOT EXISTS idx_ghost_unique_match_user 
ON public.ghost_recordings(source_match_id, user_id) 
WHERE source_match_id IS NOT NULL AND user_id IS NOT NULL;

-- Index: idx_ghost_user ON public.ghost_recordings (origin: 013_ghost_replay_engine.sql)
CREATE INDEX IF NOT EXISTS idx_ghost_user 
ON public.ghost_recordings(user_id);

-- ----------------------------------------------------------------------------
-- 5. LATEST EFFECTIVE FUNCTIONS & RPCs
-- ----------------------------------------------------------------------------

-- Function: public.cancel_private_room | latest: 011_private_rooms_system.sql | redefinitions: 1 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.cancel_private_room(
  p_match_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
BEGIN
  UPDATE public.matches
  SET status = 'cancelled'
  WHERE id = p_match_id 
    AND (player1_id = p_user_id OR player2_id = p_user_id)
    AND status = 'waiting';

  RETURN TRUE;
END;
$$;
-- Effective ALTER FUNCTION notes for public.cancel_private_room:
--   [021_admin_moderation_permissions_and_guards.sql] ALTER FUNCTION public.cancel_private_room SET search_path = public, auth; -- via DO block
-- Effective permission history for public.cancel_private_room:
--   [024a_level_question_management_schema_and_security.sql] REVOKE ALL ON FUNCTION public.cancel_private_room(UUID, UUID) FROM PUBLIC;
--   [024a_level_question_management_schema_and_security.sql] GRANT EXECUTE ON FUNCTION public.cancel_private_room(UUID, UUID) TO anon, authenticated, service_role;

-- Function: public.confirm_ready | latest: 008_multiplayer_rock_solid_fix.sql | redefinitions: 2 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.confirm_ready(
  p_match_id UUID, 
  p_user_id UUID
)
RETURNS TABLE (
  both_ready BOOLEAN, 
  match_status TEXT, 
  start_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_ready_count INT;
  v_current_status TEXT;
  v_start_time TIMESTAMPTZ;
BEGIN
  -- Guarantee this player is removed from matchmaking_queue so background heartbeats are no-ops
  DELETE FROM public.matchmaking_queue
  WHERE user_id = p_user_id;

  -- Mark this player ready
  UPDATE public.match_participants
  SET is_ready = TRUE, ready_at = NOW()
  WHERE match_id = p_match_id AND user_id = p_user_id;

  -- Count ready participants
  SELECT COUNT(*) INTO v_ready_count
  FROM public.match_participants
  WHERE match_id = p_match_id AND is_ready = TRUE;

  -- Check match status
  SELECT status, started_at INTO v_current_status, v_start_time
  FROM public.matches
  WHERE id = p_match_id;

  -- When both ready (or if already set to ready)
  IF v_ready_count >= 2 THEN
    IF v_current_status IN ('matched', 'waiting') THEN
      v_start_time := NOW() + INTERVAL '3 seconds';
      UPDATE public.matches
      SET status = 'ready', started_at = v_start_time
      WHERE id = p_match_id;
    END IF;

    RETURN QUERY SELECT TRUE, 'ready'::TEXT, v_start_time;
  ELSE
    RETURN QUERY SELECT FALSE, COALESCE(v_current_status, 'matched'), v_start_time;
  END IF;
END;
$$;
-- Effective ALTER FUNCTION notes for public.confirm_ready:
--   [021_admin_moderation_permissions_and_guards.sql] ALTER FUNCTION public.confirm_ready SET search_path = public, auth; -- via DO block
-- Effective permission history for public.confirm_ready:
--   [008_multiplayer_rock_solid_fix.sql] GRANT EXECUTE ON FUNCTION public.confirm_ready(UUID, UUID) TO authenticated;

-- Function: public.create_instant_rematch | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 3 | security_definer: True | search_path: True
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
-- Effective permission history for public.create_instant_rematch:
--   [014_ghost_world_class_hardening.sql] GRANT EXECUTE ON FUNCTION public.create_instant_rematch(UUID, UUID) TO authenticated, anon;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.create_instant_rematch(UUID, UUID) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.create_instant_rematch(UUID, UUID) TO authenticated, anon, service_role;

-- Function: public.create_private_room | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 3 | security_definer: True | search_path: True
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
-- Effective permission history for public.create_private_room:
--   [014_ghost_world_class_hardening.sql] GRANT EXECUTE ON FUNCTION public.create_private_room(UUID) TO authenticated, anon;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.create_private_room(UUID) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.create_private_room(UUID) TO authenticated, anon, service_role;

-- Function: public.find_or_create_ghost_match | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 3 | security_definer: True | search_path: True
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
-- Effective permission history for public.find_or_create_ghost_match:
--   [014_ghost_world_class_hardening.sql] GRANT EXECUTE ON FUNCTION public.find_or_create_ghost_match(UUID, INT) TO authenticated, anon;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.find_or_create_ghost_match(UUID, INT) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.find_or_create_ghost_match(UUID, INT) TO authenticated, anon, service_role;

-- Function: public.find_or_create_match | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 8 | security_definer: True | search_path: True
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
-- Effective permission history for public.find_or_create_match:
--   [014_ghost_world_class_hardening.sql] GRANT EXECUTE ON FUNCTION public.find_or_create_match(UUID, TEXT, INT, UUID) TO authenticated, anon;
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.find_or_create_match(UUID, TEXT, INT, UUID) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.find_or_create_match(UUID, TEXT, INT, UUID) TO authenticated, anon, service_role;

-- Function: public.finish_match | latest: 014_ghost_world_class_hardening.sql | redefinitions: 5 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.finish_match(p_match_id UUID, p_user_id UUID)
RETURNS TABLE(winner_user_id UUID, my_final_score INT, opponent_final_score INT, trophies_delta INT, my_total_trophies INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_my_score INT := 0;
  v_opp_id UUID;
  v_opp_score INT := 0;
  v_ghost_score INT := 0;
  v_the_winner UUID := NULL;
  v_trophies_delta INT := 0;
  v_my_new_trophies INT := 1000;
  v_prev_finished_at TIMESTAMPTZ;
  v_display_name TEXT := 'لاعب';
  v_cur_streak INT := 0;
  v_new_streak INT := 0;
  v_cur_trophies INT := 1000;
  v_arena_multiplier FLOAT := 1.2;
  v_correct_est INT := 0;
  v_match_coins INT := 0;
  v_xp_to_add INT := 0;
  v_is_friendly BOOLEAN := FALSE;
  v_is_ghost BOOLEAN := FALSE;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  DELETE FROM public.matchmaking_queue AS q WHERE q.user_id = p_user_id;

  SELECT COALESCE(m.is_friendly, FALSE), COALESCE(m.is_ghost_match, FALSE)
  INTO v_is_friendly, v_is_ghost
  FROM public.matches AS m
  WHERE m.id = p_match_id;

  SELECT mp.finished_at, COALESCE(mp.current_score, 0)
  INTO v_prev_finished_at, v_my_score
  FROM public.match_participants AS mp
  WHERE mp.match_id = p_match_id AND mp.user_id = p_user_id;

  UPDATE public.match_participants AS mp
  SET finished_at = COALESCE(mp.finished_at, NOW())
  WHERE mp.match_id = p_match_id AND mp.user_id = p_user_id
  RETURNING COALESCE(mp.current_score, 0) INTO v_my_score;

  IF v_is_ghost THEN
    SELECT
      COALESCE(m.ghost_score, 0),
      COALESCE(gr.total_score, 0)
    INTO v_opp_score, v_ghost_score
    FROM public.matches AS m
    LEFT JOIN public.ghost_recordings AS gr ON gr.id = m.source_ghost_recording_id
    WHERE m.id = p_match_id;

    v_opp_score := GREATEST(COALESCE(v_opp_score, 0), COALESCE(v_ghost_score, 0));
    v_opp_id := NULL;
  ELSE
    SELECT mp.user_id, COALESCE(mp.current_score, 0)
    INTO v_opp_id, v_opp_score
    FROM public.match_participants AS mp
    WHERE mp.match_id = p_match_id AND mp.user_id != p_user_id
    LIMIT 1;
  END IF;

  SELECT COALESCE(up.win_streak, 0) INTO v_cur_streak
  FROM public.user_progress AS up
  WHERE up.user_id = p_user_id
  LIMIT 1;
  v_cur_streak := COALESCE(v_cur_streak, 0);

  SELECT COALESCE(lb.trophies, 1000) INTO v_cur_trophies
  FROM public.leaderboard AS lb
  WHERE lb.user_id = p_user_id
  LIMIT 1;
  v_cur_trophies := COALESCE(v_cur_trophies, 1000);

  IF v_my_score > COALESCE(v_opp_score, 0) THEN
    v_the_winner := p_user_id;
    v_new_streak := v_cur_streak + 1;
    v_trophies_delta := 25 + LEAST(v_new_streak * 2, 10);
  ELSIF COALESCE(v_opp_score, 0) > v_my_score THEN
    IF v_opp_id IS NOT NULL AND EXISTS(SELECT 1 FROM auth.users AS au WHERE au.id = v_opp_id) THEN
      v_the_winner := v_opp_id;
    ELSE
      v_the_winner := NULL;
    END IF;

    IF v_is_friendly = TRUE THEN
      v_new_streak := v_cur_streak;
      v_trophies_delta := 0;
    ELSIF v_prev_finished_at IS NULL AND EXISTS (
      SELECT 1 FROM public.user_inventory AS ui
      WHERE ui.user_id = p_user_id AND ui.item_id = 'powerup_shield'
    ) THEN
      DELETE FROM public.user_inventory AS ui
      WHERE ui.user_id = p_user_id AND ui.item_id = 'powerup_shield';
      v_new_streak := v_cur_streak;
      v_trophies_delta := 0;
    ELSE
      v_new_streak := 0;
      v_trophies_delta := -12;
    END IF;
  ELSE
    v_the_winner := NULL;
    v_new_streak := v_cur_streak;
    v_trophies_delta := 5;
  END IF;

  IF v_is_friendly = TRUE THEN
    v_trophies_delta := 0;
    v_new_streak := v_cur_streak;
  END IF;

  UPDATE public.matches AS m
  SET status = 'finished', winner_id = v_the_winner
  WHERE m.id = p_match_id;

  IF v_prev_finished_at IS NULL THEN
    v_xp_to_add := COALESCE(v_my_score, 0);
    IF v_xp_to_add > 0 AND EXISTS (
      SELECT 1 FROM public.user_inventory AS ui
      WHERE ui.user_id = p_user_id AND ui.item_id = 'powerup_xp_banner'
    ) THEN
      DELETE FROM public.user_inventory AS ui
      WHERE ui.user_id = p_user_id AND ui.item_id = 'powerup_xp_banner';
      v_xp_to_add := v_xp_to_add * 2;
    END IF;

    SELECT COALESCE(
      (SELECT up.display_name FROM public.user_progress AS up WHERE up.user_id = p_user_id LIMIT 1),
      (SELECT lb.display_name FROM public.leaderboard AS lb WHERE lb.user_id = p_user_id LIMIT 1),
      'لاعب'
    ) INTO v_display_name;

    INSERT INTO public.leaderboard (
      user_id,
      display_name,
      score,
      trophies,
      wins_count,
      matches_count,
      updated_at
    )
    VALUES (
      p_user_id,
      v_display_name,
      v_xp_to_add,
      GREATEST(800, 1000 + v_trophies_delta),
      CASE WHEN v_the_winner = p_user_id THEN 1 ELSE 0 END,
      1,
      NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      score = COALESCE(public.leaderboard.score, 0) + v_xp_to_add,
      trophies = GREATEST(800, COALESCE(public.leaderboard.trophies, 1000) + v_trophies_delta),
      wins_count = COALESCE(public.leaderboard.wins_count, 0) + CASE WHEN v_the_winner = p_user_id THEN 1 ELSE 0 END,
      matches_count = COALESCE(public.leaderboard.matches_count, 0) + 1,
      updated_at = NOW()
    RETURNING trophies INTO v_my_new_trophies;

    IF v_my_new_trophies >= 1850 THEN v_arena_multiplier := 2.5;
    ELSIF v_my_new_trophies >= 1600 THEN v_arena_multiplier := 2.0;
    ELSIF v_my_new_trophies >= 1400 THEN v_arena_multiplier := 1.8;
    ELSIF v_my_new_trophies >= 1200 THEN v_arena_multiplier := 1.5;
    ELSIF v_my_new_trophies >= 1000 THEN v_arena_multiplier := 1.2;
    ELSE v_arena_multiplier := 1.0;
    END IF;

    IF v_my_score > 0 THEN
      v_correct_est := GREATEST(1, LEAST(5, FLOOR(v_my_score / 18.0)::INT));
    ELSE
      v_correct_est := 0;
    END IF;

    v_match_coins := FLOOR((10.0 + v_correct_est * 3.0) * v_arena_multiplier)::INT;

    UPDATE public.user_progress AS up
    SET
      total_score = COALESCE(up.total_score, 0) + v_xp_to_add,
      high_score = GREATEST(COALESCE(up.high_score, 0), v_xp_to_add),
      coins = COALESCE(up.coins, 100) + v_match_coins,
      win_streak = v_new_streak,
      updated_at = NOW()
    WHERE up.user_id = p_user_id;
  ELSE
    SELECT COALESCE(lb.trophies, 1000) INTO v_my_new_trophies
    FROM public.leaderboard AS lb
    WHERE lb.user_id = p_user_id;
  END IF;

  RETURN QUERY SELECT
    v_the_winner,
    COALESCE(v_my_score, 0),
    COALESCE(v_opp_score, 0),
    v_trophies_delta,
    COALESCE(v_my_new_trophies, 1000);
END;
$$;
-- Effective ALTER FUNCTION notes for public.finish_match:
--   [021_admin_moderation_permissions_and_guards.sql] ALTER FUNCTION public.finish_match SET search_path = public, auth; -- via DO block
-- Effective permission history for public.finish_match:
--   [008_multiplayer_rock_solid_fix.sql] GRANT EXECUTE ON FUNCTION public.finish_match(UUID, UUID) TO authenticated;
--   [009_glory_and_store.sql] GRANT EXECUTE ON FUNCTION public.finish_match(UUID, UUID) TO authenticated, service_role;
--   [014_ghost_world_class_hardening.sql] GRANT EXECUTE ON FUNCTION public.finish_match(UUID, UUID) TO authenticated, anon;

-- Function: public.generate_match_question_ids | latest: 014_ghost_world_class_hardening.sql | redefinitions: 1 | security_definer: False | search_path: False
CREATE OR REPLACE FUNCTION public.generate_match_question_ids()
RETURNS TEXT[]
LANGUAGE sql
VOLATILE
AS $$
  SELECT ARRAY(
    SELECT picked.cat || ':' || (FLOOR(RANDOM() * 10)::INT + 1)::TEXT || ':' || FLOOR(RANDOM() * 10)::INT::TEXT
    FROM (
      SELECT cat
      FROM UNNEST(ARRAY['quran', 'hadith', 'fiqh', 'seerah', 'history', 'aqeedah']) AS cat
      ORDER BY RANDOM()
      LIMIT 5
    ) AS picked
  );
$$;
-- Effective permission history for public.generate_match_question_ids:
--   [014_ghost_world_class_hardening.sql] GRANT EXECUTE ON FUNCTION public.generate_match_question_ids() TO authenticated, anon;

-- Function: public.join_private_room | latest: 021_admin_moderation_permissions_and_guards.sql | redefinitions: 2 | security_definer: True | search_path: True
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
-- Effective permission history for public.join_private_room:
--   [021_admin_moderation_permissions_and_guards.sql] REVOKE ALL ON FUNCTION public.join_private_room(VARCHAR, UUID) FROM PUBLIC;
--   [021_admin_moderation_permissions_and_guards.sql] GRANT EXECUTE ON FUNCTION public.join_private_room(VARCHAR, UUID) TO authenticated, anon, service_role;

-- Function: public.save_ghost_timeline | latest: 014_ghost_world_class_hardening.sql | redefinitions: 2 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.save_ghost_timeline(
  p_match_id UUID,
  p_user_id UUID,
  p_timeline JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_match RECORD;
  v_participant RECORD;
  v_user_profile RECORD;
  v_q_count INT;
  v_item JSONB;
  v_ms INT;
  v_pts INT;
  v_lb RECORD;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Hygiene Check 1: Exactly 5 questions in timeline JSON array
  IF p_timeline IS NULL OR jsonb_typeof(p_timeline) != 'array' THEN
    RETURN FALSE;
  END IF;

  v_q_count := jsonb_array_length(p_timeline);
  IF v_q_count != 5 THEN
    RETURN FALSE;
  END IF;

  -- Hygiene Check 2: Human timing floor (>= 600ms) and bounded points
  FOR i IN 0..4 LOOP
    v_item := p_timeline->i;
    v_ms := COALESCE((v_item->>'ms')::INT, 0);
    v_pts := COALESCE((v_item->>'pts')::INT, 0);
    IF v_ms < 600 OR v_pts < 0 OR v_pts > 25 THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  -- Verify Match exists and caller participated
  SELECT m.id, m.seed, m.question_ids
  INTO v_match
  FROM public.matches AS m
  WHERE m.id = p_match_id
    AND (m.player1_id = p_user_id OR m.player2_id = p_user_id);

  IF NOT FOUND OR v_match.seed IS NULL OR array_length(v_match.question_ids, 1) IS DISTINCT FROM 5 THEN
    RETURN FALSE;
  END IF;

  -- Verify Participant actually finished all 5 questions with positive score
  -- (Using mp.finished_at eliminates GH-01 race when Player 1 finishes first!)
  SELECT mp.current_score, mp.current_question_index, mp.finished_at
  INTO v_participant
  FROM public.match_participants AS mp
  WHERE mp.match_id = p_match_id AND mp.user_id = p_user_id;

  IF NOT FOUND
     OR v_participant.finished_at IS NULL
     OR COALESCE(v_participant.current_score, 0) <= 0
     OR COALESCE(v_participant.current_question_index, 0) < 5 THEN
    RETURN FALSE;
  END IF;

  SELECT
    COALESCE(up.display_name, 'فارس الأندلس') AS display_name,
    COALESCE(up.avatar_index, 0) AS avatar_index,
    COALESCE(up.equipped_frame, 'frame_wood') AS equipped_frame,
    COALESCE(up.player_level, 1) AS player_level
  INTO v_user_profile
  FROM public.user_progress AS up
  WHERE up.user_id = p_user_id
  LIMIT 1;

  SELECT COALESCE(lb.trophies, 1000) AS trophies
  INTO v_lb
  FROM public.leaderboard AS lb
  WHERE lb.user_id = p_user_id
  LIMIT 1;

  INSERT INTO public.ghost_recordings (
    source_match_id,
    user_id,
    display_name,
    avatar_index,
    equipped_frame,
    player_level,
    trophies,
    seed,
    question_ids,
    timeline,
    total_score,
    is_active,
    created_at
  )
  VALUES (
    p_match_id,
    p_user_id,
    COALESCE(v_user_profile.display_name, 'فارس الأندلس'),
    COALESCE(v_user_profile.avatar_index, 0),
    COALESCE(v_user_profile.equipped_frame, 'frame_wood'),
    COALESCE(v_user_profile.player_level, 1),
    COALESCE(v_lb.trophies, 1000),
    v_match.seed,
    v_match.question_ids,
    p_timeline,
    v_participant.current_score,
    TRUE,
    NOW()
  )
  ON CONFLICT (source_match_id, user_id) WHERE source_match_id IS NOT NULL AND user_id IS NOT NULL DO NOTHING;

  -- Soft-archive older recordings beyond 5 active per user (preserves FKs)
  UPDATE public.ghost_recordings AS g
  SET is_active = FALSE
  WHERE g.user_id = p_user_id
    AND g.is_active = TRUE
    AND g.id NOT IN (
      SELECT g2.id
      FROM public.ghost_recordings AS g2
      WHERE g2.user_id = p_user_id
        AND g2.is_active = TRUE
      ORDER BY g2.created_at DESC
      LIMIT 5
    );

  RETURN TRUE;
END;
$$;
-- Effective ALTER FUNCTION notes for public.save_ghost_timeline:
--   [021_admin_moderation_permissions_and_guards.sql] ALTER FUNCTION public.save_ghost_timeline SET search_path = public, auth; -- via DO block
-- Effective permission history for public.save_ghost_timeline:
--   [014_ghost_world_class_hardening.sql] GRANT EXECUTE ON FUNCTION public.save_ghost_timeline(UUID, UUID, JSONB) TO authenticated, anon;

-- Function: public.submit_answer | latest: 014_ghost_world_class_hardening.sql | redefinitions: 3 | security_definer: True | search_path: True
CREATE OR REPLACE FUNCTION public.submit_answer(
  p_match_id UUID,
  p_user_id UUID,
  p_question_index INT,
  p_is_correct BOOLEAN,
  p_time_left INT
)
RETURNS TABLE(new_score INT, opponent_score INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_points_earned INT := 0;
  v_my_new_score INT;
  v_opp_score INT := 0;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_is_correct THEN
    v_points_earned := 10 + GREATEST(0, LEAST(COALESCE(p_time_left, 0), 15));
  ELSE
    v_points_earned := 0;
  END IF;

  -- Idempotency guard: each question index 0..4 can only advance current_question_index once
  UPDATE public.match_participants AS mp
  SET
    current_score = COALESCE(mp.current_score, 0) + v_points_earned,
    current_question_index = p_question_index + 1
  WHERE mp.match_id = p_match_id
    AND mp.user_id = p_user_id
    AND p_question_index BETWEEN 0 AND 4
    AND COALESCE(mp.current_question_index, 0) <= p_question_index
  RETURNING mp.current_score INTO v_my_new_score;

  IF v_my_new_score IS NULL THEN
    SELECT COALESCE(mp.current_score, 0)
    INTO v_my_new_score
    FROM public.match_participants AS mp
    WHERE mp.match_id = p_match_id AND mp.user_id = p_user_id
    LIMIT 1;
  END IF;

  SELECT COALESCE(mp.current_score, 0)
  INTO v_opp_score
  FROM public.match_participants AS mp
  WHERE mp.match_id = p_match_id AND mp.user_id != p_user_id
  LIMIT 1;

  RETURN QUERY SELECT COALESCE(v_my_new_score, 0), COALESCE(v_opp_score, 0);
END;
$$;
-- Effective ALTER FUNCTION notes for public.submit_answer:
--   [021_admin_moderation_permissions_and_guards.sql] ALTER FUNCTION public.submit_answer SET search_path = public, auth; -- via DO block
-- Effective permission history for public.submit_answer:
--   [008_multiplayer_rock_solid_fix.sql] GRANT EXECUTE ON FUNCTION public.submit_answer(UUID, UUID, INT, BOOLEAN, INT) TO authenticated;
--   [014_ghost_world_class_hardening.sql] GRANT EXECUTE ON FUNCTION public.submit_answer(UUID, UUID, INT, BOOLEAN, INT) TO authenticated, anon;
