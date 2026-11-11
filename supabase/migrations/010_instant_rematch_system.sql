-- ==============================================================================
-- 🚀 MIGRATION 010: INSTANT REMATCH SYSTEM WITH IDEMPOTENCY & ANTI-FARMING
-- ==============================================================================
-- 1. Add parent_match_id and rematch_count to matches table.
-- 2. Create create_instant_rematch RPC with:
--    - Idempotency guard (returns same room if already generated).
--    - Anti-farming cap (3 consecutive matches max for trophies).
--    - Fresh seed and randomized 5-question pool.
-- ==============================================================================

-- 1. COLUMNS & INDEXES
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS parent_match_id UUID REFERENCES public.matches(id),
ADD COLUMN IF NOT EXISTS rematch_count INTEGER DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_matches_parent_rematch 
ON public.matches(parent_match_id);

-- 2. RPC: create_instant_rematch
CREATE OR REPLACE FUNCTION public.create_instant_rematch(
  p_parent_match_id UUID,
  p_user_id UUID
)
RETURNS TABLE (
  match_id UUID,
  player1_id UUID,
  player2_id UUID,
  seed BIGINT,
  question_ids TEXT[],
  is_friendly BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
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
  -- A. Verify parent match
  SELECT m.id, m.player1_id, m.player2_id, COALESCE(m.rematch_count, 0) AS count
  INTO v_old_match
  FROM public.matches AS m
  WHERE m.id = p_parent_match_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'المباراة الأصلية غير موجودة';
  END IF;

  -- Verify caller is one of the players
  IF v_old_match.player1_id != p_user_id AND v_old_match.player2_id != p_user_id THEN
    RAISE EXCEPTION 'غير مصرح لك بتجديد هذه المباراة';
  END IF;

  -- B. Check if a rematch for this parent match already exists (Idempotent Guard)
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

  -- C. Check rematch cap (>= 3 consecutive rematches become friendly)
  v_rematch_count := v_old_match.count + 1;
  IF v_rematch_count >= 3 THEN
    v_is_friendly := TRUE;
  END IF;

  -- D. Generate new seed and random questions
  v_new_seed := FLOOR(RANDOM() * 2147483647)::BIGINT;
  SELECT ARRAY[
    'quran:1:' || (FLOOR(RANDOM() * 10)::INT),
    'hadith:1:' || (FLOOR(RANDOM() * 10)::INT),
    'fiqh:1:' || (FLOOR(RANDOM() * 10)::INT),
    'seerah:1:' || (FLOOR(RANDOM() * 10)::INT),
    'aqeedah:1:' || (FLOOR(RANDOM() * 10)::INT)
  ] INTO v_new_questions;

  -- E. Insert new match
  INSERT INTO public.matches (
    parent_match_id,
    player1_id,
    player2_id,
    seed,
    question_ids,
    status,
    rematch_count,
    created_at
  )
  VALUES (
    p_parent_match_id,
    v_old_match.player1_id,
    v_old_match.player2_id,
    v_new_seed,
    v_new_questions,
    'matched',
    v_rematch_count,
    NOW()
  )
  RETURNING id INTO v_new_match_id;

  -- F. Insert participants
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
