-- 1. Add 'seed' column to 'matches' table if not exists
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS seed INT DEFAULT FLOOR(RANDOM() * 1000000);

-- 2. Add 'questions' column to 'matches' table if not exists
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS questions JSONB;

-- 3. Add 'updated_at' column to 'matchmaking_queue' table if not exists
ALTER TABLE public.matchmaking_queue ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 4. UPDATE RLS POLICY FOR User Progress (Critical for Opponent Name)
-- Check if policy exists and drop it to create the new open one
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE tablename = 'user_progress' AND policyname = 'Users can view own progress'
    ) THEN
        DROP POLICY "Users can view own progress" ON public.user_progress;
        CREATE POLICY "Anyone can view user progress" ON public.user_progress FOR SELECT USING (true);
    END IF;
END
$$;

-- Ensure policy exists even if the old one wasn't there (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE tablename = 'user_progress' AND policyname = 'Anyone can view user progress'
    ) THEN
        CREATE POLICY "Anyone can view user progress" ON public.user_progress FOR SELECT USING (true);
    END IF;
END
$$;


-- 5. Drop existing function to allow return type change
DROP FUNCTION IF EXISTS public.find_or_create_match(UUID, TEXT);

-- 6. Recreate function with full logic (Active Players Only)
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
  AND updated_at > NOW() - INTERVAL '30 seconds' -- Only active users (heartbeat)
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_opponent_id IS NOT NULL THEN
    -- Match found! Delete opponent from queue
    DELETE FROM public.matchmaking_queue WHERE user_id = v_opponent_id;
    
    v_seed := FLOOR(RANDOM() * 1000000);
    
    -- Insert new match (Handling NULL constraints)
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
      '[]'::jsonb, -- Empty questions list
      0
    )
    RETURNING id INTO v_match_id;

    -- Add participants
    INSERT INTO public.match_participants (match_id, user_id) VALUES (v_match_id, v_opponent_id);
    INSERT INTO public.match_participants (match_id, user_id) VALUES (v_match_id, p_user_id);
    
    RETURN QUERY SELECT v_match_id, v_opponent_id, p_user_id, v_seed, '[]'::jsonb, 'waiting';
  
  ELSE
    -- No match found, Add to queue
    INSERT INTO public.matchmaking_queue (user_id, app_version, updated_at)
    VALUES (p_user_id, p_app_version, NOW())
    ON CONFLICT (user_id) 
    DO UPDATE SET updated_at = NOW(); 
    
    RETURN;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
