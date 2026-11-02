-- 1. CLEANUP: Remove all stuck users from the queue (Start Fresh)
TRUNCATE TABLE public.matchmaking_queue;

-- 2. SCHEMA: Ensure all columns exist
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS seed INT DEFAULT FLOOR(RANDOM() * 1000000);
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS questions JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.matchmaking_queue ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 3. FUNCTION: Drop and Recreate with STRICT 30-second active check
DROP FUNCTION IF EXISTS public.find_or_create_match(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.find_or_create_match(p_user_id UUID, p_app_version TEXT)
RETURNS TABLE (
  match_id UUID,
  player1_id UUID,
  player2_id UUID,
  seed INT,
  questions JSONB,
  status TEXT
) AS $$
DECLARE
  v_match_id UUID;
  v_opponent_id UUID;
  v_seed INT;
BEGIN
  -- Search for opponent WHO IS ACTIVE (updated recently)
  SELECT user_id INTO v_opponent_id
  FROM public.matchmaking_queue
  WHERE user_id != p_user_id
  AND updated_at > NOW() - INTERVAL '30 seconds' -- STRICT CHECK: Must be active in last 30s
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_opponent_id IS NOT NULL THEN
    -- Match found! Delete from queue
    DELETE FROM public.matchmaking_queue WHERE user_id = v_opponent_id;
    
    v_seed := FLOOR(RANDOM() * 1000000);
    
    -- Insert new match
    INSERT INTO public.matches (
      player1_id, 
      player2_id, 
      status, 
      seed, 
      questions, 
      current_question
    )
    VALUES (
      v_opponent_id, 
      p_user_id, 
      'waiting', 
      v_seed, 
      '[]'::jsonb,
      0
    )
    RETURNING id INTO v_match_id;

    -- Add participants
    INSERT INTO public.match_participants (match_id, user_id) VALUES (v_match_id, v_opponent_id);
    INSERT INTO public.match_participants (match_id, user_id) VALUES (v_match_id, p_user_id);
    
    RETURN QUERY SELECT v_match_id, v_opponent_id, p_user_id, v_seed, '[]'::jsonb, 'waiting';
  
  ELSE
    -- No match found, Add to queue or Update existing
    INSERT INTO public.matchmaking_queue (user_id, app_version, updated_at)
    VALUES (p_user_id, p_app_version, NOW())
    ON CONFLICT (user_id) 
    DO UPDATE SET updated_at = NOW(); -- Critical: Update heartbeat
    
    RETURN;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
