-- ==============================================================================
-- 🚀 MIGRATION 011: PRIVATE ROOMS WITH 6-DIGIT PIN & 3-MINUTE EXPIRATION
-- ==============================================================================
-- 1. Add room_code, is_private, and expires_at to matches table.
-- 2. Create create_private_room RPC (generates 6-digit PIN, 3-min timeout, seed, questions).
-- 3. Create join_private_room RPC (validates code, expiration, guest slot, and matches room).
-- 4. Create cancel_private_room RPC (safely closes room when host cancels or navigates back).
-- ==============================================================================

-- 1. COLUMNS & INDEXES
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS room_code VARCHAR(6),
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Allow player2_id to be NULL while private room is waiting for guest
ALTER TABLE public.matches ALTER COLUMN player2_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_matches_room_code 
ON public.matches(room_code) 
WHERE room_code IS NOT NULL;

-- 2. RPC: create_private_room
CREATE OR REPLACE FUNCTION public.create_private_room(
  p_host_id UUID
)
RETURNS TABLE (
  match_id UUID,
  room_code VARCHAR(6),
  expires_at TIMESTAMPTZ,
  seed BIGINT,
  question_ids TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_match_id UUID;
  v_code VARCHAR(6);
  v_expires TIMESTAMPTZ;
  v_seed BIGINT;
  v_questions TEXT[];
BEGIN
  -- Cancel previous waiting private rooms created by this host
  UPDATE public.matches
  SET status = 'cancelled'
  WHERE player1_id = p_host_id 
    AND status = 'waiting' 
    AND is_private = TRUE;

  -- Generate unique 6-digit room code
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

  -- Pick 5 random questions across categories
  SELECT ARRAY[
    'quran:1:' || (FLOOR(RANDOM() * 10)::INT),
    'hadith:1:' || (FLOOR(RANDOM() * 10)::INT),
    'fiqh:1:' || (FLOOR(RANDOM() * 10)::INT),
    'seerah:1:' || (FLOOR(RANDOM() * 10)::INT),
    'aqeedah:1:' || (FLOOR(RANDOM() * 10)::INT)
  ] INTO v_questions;

  -- Insert match
  INSERT INTO public.matches (
    player1_id,
    seed,
    question_ids,
    status,
    is_private,
    room_code,
    expires_at,
    created_at
  )
  VALUES (
    p_host_id,
    v_seed,
    v_questions,
    'waiting',
    TRUE,
    v_code,
    v_expires,
    NOW()
  )
  RETURNING id INTO v_match_id;

  -- Insert host into participants
  INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score)
  VALUES (v_match_id, p_host_id, TRUE, 0);

  RETURN QUERY SELECT v_match_id, v_code, v_expires, v_seed, v_questions;
END;
$$;

-- 3. RPC: join_private_room
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
AS $$
#variable_conflict use_column
DECLARE
  v_match RECORD;
BEGIN
  -- Search for active private room
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

  -- Add guest and set match status to matched
  UPDATE public.matches
  SET player2_id = p_guest_id, status = 'matched'
  WHERE id = v_match.id;

  -- Insert guest into participants
  INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score)
  VALUES (v_match.id, p_guest_id, TRUE, 0);

  RETURN QUERY SELECT v_match.id, v_match.player1_id, v_match.seed, v_match.question_ids;
END;
$$;

-- 4. RPC: cancel_private_room
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
