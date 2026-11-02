-- Migration: 004_multiplayer_fix.sql
-- Description: Fixes for online multiplayer to prevent race conditions
-- Date: 2026-02-02

-- ============================================
-- 1. DROP OLD CONSTRAINT FIRST
-- ============================================

-- Drop old constraint FIRST (before any updates)
ALTER TABLE matches DROP CONSTRAINT IF EXISTS matches_status_check;

-- ============================================
-- 2. UPDATE EXISTING ROWS 
-- ============================================

-- Now we can safely update old status values
UPDATE matches SET status = 'playing' WHERE status = 'active';
UPDATE matches SET status = 'matched' WHERE status = 'waiting';

-- ============================================
-- 3. ADD NEW CONSTRAINT
-- ============================================

ALTER TABLE matches ADD CONSTRAINT matches_status_check 
CHECK (status IN ('waiting', 'matched', 'ready', 'playing', 'finished'));

-- ============================================
-- 2. ADD NEW COLUMNS TO MATCHES TABLE
-- ============================================

-- question_ids: Array of question identifiers (category:level:index format)
ALTER TABLE matches ADD COLUMN IF NOT EXISTS question_ids TEXT[];

-- current_question: Index of the current question (0-based)
ALTER TABLE matches ADD COLUMN IF NOT EXISTS current_question INT DEFAULT 0;

-- started_at: When the game actually started (after both ready)
ALTER TABLE matches ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;

-- ============================================
-- 3. ADD READY CONFIRMATION TO PARTICIPANTS
-- ============================================

ALTER TABLE match_participants ADD COLUMN IF NOT EXISTS is_ready BOOLEAN DEFAULT FALSE;
ALTER TABLE match_participants ADD COLUMN IF NOT EXISTS ready_at TIMESTAMPTZ;

-- ============================================
-- 4. DROP OLD FUNCTIONS (required to change return types)
-- ============================================

DROP FUNCTION IF EXISTS find_or_create_match(uuid, text);
DROP FUNCTION IF EXISTS confirm_ready(uuid, uuid);
DROP FUNCTION IF EXISTS submit_answer(uuid, uuid, int, boolean, int);
DROP FUNCTION IF EXISTS finish_match(uuid, uuid);

-- ============================================
-- 5. UPDATE find_or_create_match FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION find_or_create_match(p_user_id uuid, p_app_version text)
RETURNS TABLE (match_id uuid, player1_id uuid, player2_id uuid, seed bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  waiting_user_id uuid;
  new_match_id uuid;
  random_seed bigint;
  selected_questions TEXT[];
BEGIN
  -- 1. Try to find a waiting user (Locking the row to prevent race conditions)
  DELETE FROM matchmaking_queue
  WHERE id = (
    SELECT id FROM matchmaking_queue
    WHERE user_id != p_user_id
    AND app_version = p_app_version
    ORDER BY created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
  )
  RETURNING user_id INTO waiting_user_id;

  -- 2. If we found someone
  IF waiting_user_id IS NOT NULL THEN
    -- Generate a big random seed for deterministic question selection
    random_seed := floor(random() * 2147483647)::bigint;
    
    -- Generate 5 random question identifiers
    -- Format: 'category:level:question_index'
    -- We use the seed to make this deterministic
    SELECT ARRAY[
      'quran:1:' || (floor(random() * 10)::int),
      'hadith:1:' || (floor(random() * 10)::int),
      'fiqh:1:' || (floor(random() * 10)::int),
      'seerah:1:' || (floor(random() * 10)::int),
      'aqeedah:1:' || (floor(random() * 10)::int)
    ] INTO selected_questions;

    -- Create the match with status 'matched' (not active yet)
    INSERT INTO matches (player1_id, player2_id, seed, status, question_ids, current_question)
    VALUES (waiting_user_id, p_user_id, random_seed, 'matched', selected_questions, 0)
    RETURNING id INTO new_match_id;

    -- Initialize participants (not ready yet)
    INSERT INTO match_participants (match_id, user_id, is_ready) 
    VALUES (new_match_id, waiting_user_id, FALSE);
    
    INSERT INTO match_participants (match_id, user_id, is_ready) 
    VALUES (new_match_id, p_user_id, FALSE);

    -- Return match info
    RETURN QUERY SELECT new_match_id, waiting_user_id, p_user_id, random_seed;
  
  ELSE
    -- 3. No one found, add self to queue
    INSERT INTO matchmaking_queue (user_id, app_version)
    VALUES (p_user_id, p_app_version)
    ON CONFLICT (user_id) DO UPDATE SET 
      app_version = EXCLUDED.app_version,
      created_at = NOW();
    
    RETURN; -- Return nothing (waiting)
  END IF;
END;
$$;

-- ============================================
-- 5. CREATE confirm_ready FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION confirm_ready(p_match_id uuid, p_user_id uuid)
RETURNS TABLE (both_ready boolean, match_status text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  ready_count int;
  current_status text;
BEGIN
  -- Update this player's ready status
  UPDATE match_participants
  SET is_ready = TRUE, ready_at = NOW()
  WHERE match_id = p_match_id AND user_id = p_user_id;

  -- Count how many are ready
  SELECT COUNT(*) INTO ready_count
  FROM match_participants
  WHERE match_id = p_match_id AND is_ready = TRUE;

  -- Get current match status
  SELECT status INTO current_status
  FROM matches
  WHERE id = p_match_id;

  -- If both players are ready, update match to 'ready' then 'playing'
  IF ready_count >= 2 AND current_status = 'matched' THEN
    UPDATE matches
    SET status = 'ready', started_at = NOW()
    WHERE id = p_match_id;
    
    RETURN QUERY SELECT TRUE, 'ready'::text;
  ELSE
    RETURN QUERY SELECT FALSE, current_status;
  END IF;
END;
$$;

-- ============================================
-- 6. CREATE submit_answer FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION submit_answer(
  p_match_id uuid, 
  p_user_id uuid, 
  p_question_index int,
  p_is_correct boolean,
  p_time_left int
)
RETURNS TABLE (new_score int, opponent_score int)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  points_earned int;
  my_new_score int;
  opp_score int;
BEGIN
  -- Calculate points (10 for correct + time bonus)
  IF p_is_correct THEN
    points_earned := 10 + p_time_left;
  ELSE
    points_earned := 0;
  END IF;

  -- Update player's score and question index
  UPDATE match_participants
  SET 
    current_score = current_score + points_earned,
    current_question_index = p_question_index + 1
  WHERE match_id = p_match_id AND user_id = p_user_id
  RETURNING current_score INTO my_new_score;

  -- Get opponent's score
  SELECT current_score INTO opp_score
  FROM match_participants
  WHERE match_id = p_match_id AND user_id != p_user_id;

  RETURN QUERY SELECT my_new_score, COALESCE(opp_score, 0);
END;
$$;

-- ============================================
-- 7. CREATE finish_match FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION finish_match(p_match_id uuid, p_user_id uuid)
RETURNS TABLE (winner_user_id uuid, my_final_score int, opponent_final_score int)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  my_score int;
  opp_id uuid;
  opp_score int;
  the_winner uuid;
BEGIN
  -- Mark this player as finished
  UPDATE match_participants
  SET finished_at = NOW()
  WHERE match_id = p_match_id AND user_id = p_user_id
  RETURNING current_score INTO my_score;

  -- Get opponent info
  SELECT user_id, current_score INTO opp_id, opp_score
  FROM match_participants
  WHERE match_id = p_match_id AND user_id != p_user_id;

  -- Check if both finished
  IF (SELECT COUNT(*) FROM match_participants WHERE match_id = p_match_id AND finished_at IS NOT NULL) >= 2 THEN
    -- Determine winner
    IF my_score > COALESCE(opp_score, 0) THEN
      the_winner := p_user_id;
    ELSIF COALESCE(opp_score, 0) > my_score THEN
      the_winner := opp_id;
    ELSE
      the_winner := NULL; -- Draw
    END IF;

    -- Update match status
    UPDATE matches
    SET status = 'finished', winner_id = the_winner
    WHERE id = p_match_id;
  END IF;

  RETURN QUERY SELECT the_winner, my_score, COALESCE(opp_score, 0);
END;
$$;

-- ============================================
-- 8. GRANT EXECUTE PERMISSIONS
-- ============================================

GRANT EXECUTE ON FUNCTION confirm_ready(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION submit_answer(uuid, uuid, int, boolean, int) TO authenticated;
GRANT EXECUTE ON FUNCTION finish_match(uuid, uuid) TO authenticated;

-- ============================================
-- 9. ADD INSERT POLICY FOR PARTICIPANTS
-- ============================================

-- Allow the RPC functions to insert (they run as SECURITY DEFINER)
DROP POLICY IF EXISTS "System creates participants" ON match_participants;
CREATE POLICY "System creates participants" ON match_participants FOR INSERT WITH CHECK (true);
