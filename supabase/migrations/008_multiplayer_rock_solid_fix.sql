-- ==============================================================================
-- 🚀 MIGRATION 008: ROCK-SOLID MULTIPLAYER SYNCHRONIZATION & SCORING SYSTEM
-- ==============================================================================
-- This migration permanently fixes:
-- 1. Realtime notification dropping (REPLICA IDENTITY FULL).
-- 2. Zombie / Ghost matches and sticky offline opponents (Immediate cleanup on search & finish).
-- 3. Stale queue cleanup (15-second active heartbeat window + auto-delete on confirm_ready).
-- 4. Missing submit_answer RPC (which caused 0-0 perpetual ties!).
-- 5. Server-side Battle Trophies, winner resolution, and leaderboard/progress score persistence.
-- ==============================================================================

-- 1. ENABLE FULL REPLICA IDENTITY FOR REALTIME RLS EVENTS
ALTER TABLE public.matches REPLICA IDENTITY FULL;
ALTER TABLE public.match_participants REPLICA IDENTITY FULL;
ALTER TABLE public.matchmaking_queue REPLICA IDENTITY FULL;

-- Ensure tables are in the realtime publication
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'matches') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'match_participants') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.match_participants;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'matchmaking_queue') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.matchmaking_queue;
  END IF;
END $$;

-- 2. ADD TROPHIES & STATS COLUMNS TO LEADERBOARD
ALTER TABLE public.leaderboard ADD COLUMN IF NOT EXISTS trophies INTEGER DEFAULT 1000;
ALTER TABLE public.leaderboard ADD COLUMN IF NOT EXISTS wins_count INTEGER DEFAULT 0;
ALTER TABLE public.leaderboard ADD COLUMN IF NOT EXISTS matches_count INTEGER DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_leaderboard_trophies ON public.leaderboard(trophies DESC);

-- 3. CLEAN UP ALL CURRENT ZOMBIE MATCHES & STALE QUEUE IN DATABASE
TRUNCATE TABLE public.matchmaking_queue;

UPDATE public.matches
SET status = 'finished'
WHERE status != 'finished';

-- 3.5 DROP EXISTING FUNCTIONS TO ALLOW CLEAN RECREATION
DROP FUNCTION IF EXISTS public.find_or_create_match(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.find_or_create_match(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.confirm_ready(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.submit_answer(UUID, UUID, INT, BOOLEAN, INT) CASCADE;
DROP FUNCTION IF EXISTS public.finish_match(UUID, UUID) CASCADE;

-- ==============================================================================
-- 4. FUNCTION: find_or_create_match (Zero Ghost Rooms & Strict Active Queue)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.find_or_create_match(
  p_user_id UUID, 
  p_app_version TEXT DEFAULT '1.0.4'
)
RETURNS TABLE (
  match_id UUID, 
  player1_id UUID, 
  player2_id UUID, 
  seed BIGINT,
  question_ids TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_opponent_id UUID;
  v_match_id UUID;
  v_seed BIGINT;
  v_question_ids TEXT[];
BEGIN
  -- A. Clean stale queue rows (strictly 15 seconds window; client heartbeats every 10s)
  DELETE FROM public.matchmaking_queue
  WHERE updated_at < NOW() - INTERVAL '15 seconds';

  -- B. IMMEDIATELY close ANY previous unfinished match for this user!
  -- (If a user is searching for a new match, any previous room is 100% over.
  --  This prevents listenForMatchFound() from EVER picking up an old/ghost room!)
  UPDATE public.matches AS m
  SET status = 'finished'
  WHERE (m.player1_id = p_user_id OR m.player2_id = p_user_id)
    AND m.status != 'finished';

  -- C. Search for an ACTIVE opponent in the queue (updated within last 15 seconds)
  DELETE FROM public.matchmaking_queue
  WHERE id = (
    SELECT q.id FROM public.matchmaking_queue AS q
    WHERE q.user_id != p_user_id
      AND q.updated_at > NOW() - INTERVAL '15 seconds'
    ORDER BY q.created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
  )
  RETURNING user_id INTO v_opponent_id;

  -- D. If opponent found, create new fresh match
  IF v_opponent_id IS NOT NULL THEN
    -- Ensure neither player remains in the queue
    DELETE FROM public.matchmaking_queue
    WHERE user_id IN (p_user_id, v_opponent_id);

    -- Also close any previous unfinished matches for the opponent
    UPDATE public.matches AS m
    SET status = 'finished'
    WHERE (m.player1_id = v_opponent_id OR m.player2_id = v_opponent_id)
      AND m.status != 'finished';

    v_seed := FLOOR(RANDOM() * 2147483647)::BIGINT;

    -- Pick 5 random questions across categories
    SELECT ARRAY[
      'quran:1:' || (FLOOR(RANDOM() * 10)::INT),
      'hadith:1:' || (FLOOR(RANDOM() * 10)::INT),
      'fiqh:1:' || (FLOOR(RANDOM() * 10)::INT),
      'seerah:1:' || (FLOOR(RANDOM() * 10)::INT),
      'aqeedah:1:' || (FLOOR(RANDOM() * 10)::INT)
    ] INTO v_question_ids;

    -- Insert match with status 'matched'
    INSERT INTO public.matches (
      player1_id, 
      player2_id, 
      seed, 
      status, 
      question_ids, 
      current_question, 
      created_at
    )
    VALUES (
      v_opponent_id, 
      p_user_id, 
      v_seed, 
      'matched', 
      v_question_ids, 
      0, 
      NOW()
    )
    RETURNING id INTO v_match_id;

    -- Insert participants with clean initial state
    INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score, current_question_index)
    VALUES 
      (v_match_id, v_opponent_id, FALSE, 0, 0),
      (v_match_id, p_user_id, FALSE, 0, 0);

    RETURN QUERY SELECT v_match_id, v_opponent_id, p_user_id, v_seed, v_question_ids;
  ELSE
    -- E. No opponent found, enter or update self in queue
    INSERT INTO public.matchmaking_queue (user_id, app_version, updated_at, created_at)
    VALUES (p_user_id, COALESCE(p_app_version, '1.0.4'), NOW(), NOW())
    ON CONFLICT (user_id) DO UPDATE SET
      app_version = EXCLUDED.app_version,
      updated_at = NOW();

    RETURN; -- Returns empty (waiting)
  END IF;
END;
$$;

-- ==============================================================================
-- 5. FUNCTION: confirm_ready (Synchronized Start & Queue Purge)
-- ==============================================================================
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

-- ==============================================================================
-- 6. FUNCTION: submit_answer (Live Question Scoring & Progress Sync)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.submit_answer(
  p_match_id UUID, 
  p_user_id UUID, 
  p_question_index INT,
  p_is_correct BOOLEAN,
  p_time_left INT
)
RETURNS TABLE (
  new_score INT, 
  opponent_score INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_points_earned INT := 0;
  v_my_new_score INT := 0;
  v_opp_score INT := 0;
BEGIN
  -- Calculate points: 10 base points for correct answer + speed bonus (0..15)
  IF p_is_correct THEN
    v_points_earned := 10 + GREATEST(0, LEAST(COALESCE(p_time_left, 0), 15));
  ELSE
    v_points_earned := 0;
  END IF;

  -- Update player's score and question index in match_participants
  UPDATE public.match_participants
  SET 
    current_score = COALESCE(current_score, 0) + v_points_earned,
    current_question_index = p_question_index + 1
  WHERE match_id = p_match_id AND user_id = p_user_id
  RETURNING current_score INTO v_my_new_score;

  -- Get opponent's current score
  SELECT COALESCE(current_score, 0) INTO v_opp_score
  FROM public.match_participants
  WHERE match_id = p_match_id AND user_id != p_user_id
  LIMIT 1;

  RETURN QUERY SELECT COALESCE(v_my_new_score, 0), COALESCE(v_opp_score, 0);
END;
$$;

-- ==============================================================================
-- 7. FUNCTION: finish_match (Atomic Scoring, Trophy Calculation & Room Closure)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.finish_match(
  p_match_id UUID, 
  p_user_id UUID
)
RETURNS TABLE (
  winner_user_id UUID, 
  my_final_score INT, 
  opponent_final_score INT,
  trophies_delta INT,
  my_total_trophies INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_my_score INT := 0;
  v_opp_id UUID;
  v_opp_score INT := 0;
  v_the_winner UUID := NULL;
  v_trophies_delta INT := 0;
  v_my_new_trophies INT := 1000;
  v_prev_finished_at TIMESTAMPTZ;
  v_display_name TEXT := 'لاعب';
BEGIN
  -- Ensure user is not in matchmaking queue
  DELETE FROM public.matchmaking_queue WHERE user_id = p_user_id;

  -- Check if this player already finished (prevent double-counting)
  SELECT finished_at, COALESCE(current_score, 0)
  INTO v_prev_finished_at, v_my_score
  FROM public.match_participants
  WHERE match_id = p_match_id AND user_id = p_user_id;

  -- Mark current player finished
  UPDATE public.match_participants
  SET finished_at = COALESCE(finished_at, NOW())
  WHERE match_id = p_match_id AND user_id = p_user_id
  RETURNING COALESCE(current_score, 0) INTO v_my_score;

  -- Get opponent info
  SELECT user_id, COALESCE(current_score, 0)
  INTO v_opp_id, v_opp_score
  FROM public.match_participants
  WHERE match_id = p_match_id AND user_id != p_user_id
  LIMIT 1;

  -- Determine Winner & Trophies
  IF v_my_score > COALESCE(v_opp_score, 0) THEN
    v_the_winner := p_user_id;
    v_trophies_delta := 25;
  ELSIF COALESCE(v_opp_score, 0) > v_my_score THEN
    v_the_winner := v_opp_id;
    v_trophies_delta := -12;
  ELSE
    v_the_winner := NULL; -- Draw
    v_trophies_delta := 5;
  END IF;

  -- CRITICAL: Immediately mark match as 'finished' so it NEVER becomes a ghost room!
  -- (OnlineGameScreen does not listen to matches.status, so an opponent still on their
  --  last question is unaffected, and when they call finish_match, winner_id updates with final scores)
  UPDATE public.matches
  SET status = 'finished', winner_id = v_the_winner
  WHERE id = p_match_id;

  -- Only add points & trophies if this player hasn't already called finish_match for this match
  IF v_prev_finished_at IS NULL THEN
    -- Get display_name from user_progress or leaderboard if available
    SELECT COALESCE(
      (SELECT up.display_name FROM public.user_progress up WHERE up.user_id = p_user_id LIMIT 1),
      (SELECT lb.display_name FROM public.leaderboard lb WHERE lb.user_id = p_user_id LIMIT 1),
      'لاعب'
    ) INTO v_display_name;

    -- ATOMICALLY UPDATE LEADERBOARD & TROPHIES FOR CALLING PLAYER
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
      v_my_score, 
      GREATEST(0, 1000 + v_trophies_delta), 
      CASE WHEN v_the_winner = p_user_id THEN 1 ELSE 0 END, 
      1, 
      NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      score = COALESCE(public.leaderboard.score, 0) + v_my_score,
      trophies = GREATEST(0, COALESCE(public.leaderboard.trophies, 1000) + v_trophies_delta),
      wins_count = COALESCE(public.leaderboard.wins_count, 0) + CASE WHEN v_the_winner = p_user_id THEN 1 ELSE 0 END,
      matches_count = COALESCE(public.leaderboard.matches_count, 0) + 1,
      updated_at = NOW()
    RETURNING trophies INTO v_my_new_trophies;

    -- Also update user_progress total_score & high_score
    UPDATE public.user_progress
    SET 
      total_score = COALESCE(total_score, 0) + v_my_score,
      high_score = GREATEST(COALESCE(high_score, 0), v_my_score),
      updated_at = NOW()
    WHERE user_id = p_user_id;
  ELSE
    SELECT COALESCE(trophies, 1000) INTO v_my_new_trophies
    FROM public.leaderboard
    WHERE user_id = p_user_id;
  END IF;

  RETURN QUERY SELECT 
    v_the_winner, 
    COALESCE(v_my_score, 0), 
    COALESCE(v_opp_score, 0), 
    v_trophies_delta, 
    COALESCE(v_my_new_trophies, 1000);
END;
$$;

-- 8. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION public.find_or_create_match(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_ready(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_answer(UUID, UUID, INT, BOOLEAN, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finish_match(UUID, UUID) TO authenticated;
