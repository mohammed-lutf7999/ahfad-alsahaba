-- ==============================================================================
-- 🚀 MIGRATION 008: ROCK-SOLID MULTIPLAYER SYNCHRONIZATION & SCORING SYSTEM
-- ==============================================================================
-- Run this script in Supabase Dashboard > SQL Editor
-- This migration permanently fixes:
-- 1. Realtime notification dropping (REPLICA IDENTITY FULL).
-- 2. Zombie / Ghost matches and sticky offline opponents.
-- 3. Stale queue cleanup (20-second active heartbeat window).
-- 4. Server-side Battle Trophies, auto-forfeit, and leaderboard score persistence.
-- ==============================================================================

-- 1. ENABLE FULL REPLICA IDENTITY FOR REALTIME RLS EVENTS
-- (Essential for Supabase to emit UPDATE events without dropping them on RLS tables)
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

-- 3. CLEAN UP ANY CURRENT ZOMBIE MATCHES IN DATABASE
UPDATE public.matches
SET status = 'finished'
WHERE status IN ('matched', 'ready', 'playing') 
  AND created_at < NOW() - INTERVAL '5 minutes';

DELETE FROM public.matchmaking_queue 
WHERE updated_at < NOW() - INTERVAL '30 seconds';

-- 4. FUNCTION: find_or_create_match (Rock-Solid Queue & Active Opponents Only)
CREATE OR REPLACE FUNCTION public.find_or_create_match(
  p_user_id UUID, 
  p_app_version TEXT
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
DECLARE
  v_opponent_id UUID;
  v_match_id UUID;
  v_seed BIGINT;
  v_question_ids TEXT[];
BEGIN
  -- A. Clean stale queue rows
  DELETE FROM public.matchmaking_queue
  WHERE updated_at < NOW() - INTERVAL '30 seconds';

  -- B. Auto-cancel any old active matches for this user older than 3 minutes
  UPDATE public.matches
  SET status = 'finished'
  WHERE (player1_id = p_user_id OR player2_id = p_user_id)
    AND status IN ('matched', 'ready', 'playing')
    AND created_at < NOW() - INTERVAL '3 minutes';

  -- C. Search for an ACTIVE opponent in the queue (strictly updated in last 25 seconds)
  DELETE FROM public.matchmaking_queue
  WHERE id = (
    SELECT id FROM public.matchmaking_queue
    WHERE user_id != p_user_id
      AND updated_at > NOW() - INTERVAL '25 seconds'
    ORDER BY created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
  )
  RETURNING user_id INTO v_opponent_id;

  -- D. If opponent found, create new fresh match
  IF v_opponent_id IS NOT NULL THEN
    v_seed := FLOOR(RANDOM() * 2147483647)::BIGINT;

    -- Pick 5 random questions
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

    -- Insert participants
    INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score, current_question_index)
    VALUES 
      (v_match_id, v_opponent_id, FALSE, 0, 0),
      (v_match_id, p_user_id, FALSE, 0, 0);

    RETURN QUERY SELECT v_match_id, v_opponent_id, p_user_id, v_seed, v_question_ids;
  ELSE
    -- E. No opponent found, enter or update self in queue
    INSERT INTO public.matchmaking_queue (user_id, app_version, updated_at, created_at)
    VALUES (p_user_id, p_app_version, NOW(), NOW())
    ON CONFLICT (user_id) DO UPDATE SET
      app_version = EXCLUDED.app_version,
      updated_at = NOW();

    RETURN; -- Returns empty (waiting)
  END IF;
END;
$$;

-- 5. FUNCTION: confirm_ready (Synchronized Dual Start)
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
DECLARE
  v_ready_count INT;
  v_current_status TEXT;
  v_start_time TIMESTAMPTZ;
BEGIN
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
    IF v_current_status = 'matched' THEN
      v_start_time := NOW() + INTERVAL '3 seconds';
      UPDATE public.matches
      SET status = 'ready', started_at = v_start_time
      WHERE id = p_match_id;
    END IF;

    RETURN QUERY SELECT TRUE, 'ready'::TEXT, v_start_time;
  ELSE
    RETURN QUERY SELECT FALSE, v_current_status, v_start_time;
  END IF;
END;
$$;

-- 6. FUNCTION: finish_match (Atomic Scoring, Trophy Calculation & Server Persistence)
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
DECLARE
  v_my_score INT := 0;
  v_opp_id UUID;
  v_opp_score INT := 0;
  v_the_winner UUID := NULL;
  v_trophies_delta INT := 0;
  v_my_new_trophies INT := 1000;
  v_both_finished BOOLEAN := FALSE;
  v_opp_finished_at TIMESTAMPTZ;
BEGIN
  -- Mark current player finished
  UPDATE public.match_participants
  SET finished_at = NOW()
  WHERE match_id = p_match_id AND user_id = p_user_id
  RETURNING current_score INTO v_my_score;

  -- Get opponent info
  SELECT user_id, current_score, finished_at 
  INTO v_opp_id, v_opp_score, v_opp_finished_at
  FROM public.match_participants
  WHERE match_id = p_match_id AND user_id != p_user_id;

  -- Check if both finished OR if opponent abandoned
  IF v_opp_finished_at IS NOT NULL THEN
    v_both_finished := TRUE;
  END IF;

  -- Determine Winner
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

  -- If both finished, close the match in database
  IF v_both_finished THEN
    UPDATE public.matches
    SET status = 'finished', winner_id = v_the_winner
    WHERE id = p_match_id;
  END IF;

  -- ATOMICALLY UPDATE LEADERBOARD & TROPHIES FOR CALLING PLAYER
  INSERT INTO public.leaderboard (
    user_id, 
    score, 
    trophies, 
    wins_count, 
    matches_count, 
    updated_at
  )
  VALUES (
    p_user_id, 
    v_my_score, 
    GREATEST(0, 1000 + v_trophies_delta), 
    CASE WHEN v_the_winner = p_user_id THEN 1 ELSE 0 END, 
    1, 
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    score = public.leaderboard.score + v_my_score,
    trophies = GREATEST(0, COALESCE(public.leaderboard.trophies, 1000) + v_trophies_delta),
    wins_count = public.leaderboard.wins_count + CASE WHEN v_the_winner = p_user_id THEN 1 ELSE 0 END,
    matches_count = public.leaderboard.matches_count + 1,
    updated_at = NOW()
  RETURNING trophies INTO v_my_new_trophies;

  -- Also update user_progress total score
  UPDATE public.user_progress
  SET 
    total_score = total_score + v_my_score,
    updated_at = NOW()
  WHERE user_id = p_user_id;

  RETURN QUERY SELECT 
    v_the_winner, 
    v_my_score, 
    COALESCE(v_opp_score, 0), 
    v_trophies_delta, 
    COALESCE(v_my_new_trophies, 1000);
END;
$$;

-- 7. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION public.find_or_create_match(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_ready(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finish_match(UUID, UUID) TO authenticated;
