-- =========================================================================
-- Milestone 14 (Phase 0): World-Class Ghost Replay & Matchmaking Hardening
-- Fixes: GH-01 (save timing & status race), GH-02 (rematch consistency),
--        GH-03 (15s deterministic pts & total_score), GH-04 (level & Versus),
--        Ghost Hijacking (player2_id = NULL & exclude ghost from participants),
--        Self-Feeding Flywheel (record honest human plays in ghost matches),
--        Full 600-Question Coverage (6 categories x levels 1..10),
--        Last-Millisecond Human Match Race Guard, Zero-Trust auth.uid().
-- =========================================================================

-- 1. Add soft-archival flag so old recordings retire cleanly without breaking
--    matches.source_ghost_recording_id foreign keys.
ALTER TABLE public.ghost_recordings
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_ghost_active_trophies
  ON public.ghost_recordings (is_active, trophies, created_at DESC);

-- 2. Reconcile the 3 seeded founding ghosts to the canonical 15-second
--    match scoring formula: pts = 10 + FLOOR((15000 - ms) / 1000) when ok = true.
UPDATE public.ghost_recordings
SET
  total_score = 83,
  timeline = '[
    {"q": 0, "ms": 2850, "ans": 1, "ok": true,  "pts": 22},
    {"q": 1, "ms": 4120, "ans": 0, "ok": true,  "pts": 20},
    {"q": 2, "ms": 3200, "ans": 2, "ok": false, "pts": 0},
    {"q": 3, "ms": 2100, "ans": 3, "ok": true,  "pts": 22},
    {"q": 4, "ms": 5300, "ans": 1, "ok": true,  "pts": 19}
  ]'::JSONB
WHERE id = '4930d9c8-d617-41e9-9e79-0aaba1f9a0a4'::UUID
  AND user_id IS NULL;

UPDATE public.ghost_recordings
SET
  total_score = 107,
  timeline = '[
    {"q": 0, "ms": 1950, "ans": 0, "ok": true, "pts": 23},
    {"q": 1, "ms": 3400, "ans": 2, "ok": true, "pts": 21},
    {"q": 2, "ms": 2800, "ans": 1, "ok": true, "pts": 22},
    {"q": 3, "ms": 4600, "ans": 0, "ok": true, "pts": 20},
    {"q": 4, "ms": 3100, "ans": 2, "ok": true, "pts": 21}
  ]'::JSONB
WHERE id = 'dc1de175-eb86-4249-bef3-2e52140d9340'::UUID
  AND user_id IS NULL;

UPDATE public.ghost_recordings
SET
  total_score = 89,
  timeline = '[
    {"q": 0, "ms": 2100, "ans": 3, "ok": true,  "pts": 22},
    {"q": 1, "ms": 2900, "ans": 1, "ok": true,  "pts": 22},
    {"q": 2, "ms": 3800, "ans": 0, "ok": false, "pts": 0},
    {"q": 3, "ms": 1800, "ans": 2, "ok": true,  "pts": 23},
    {"q": 4, "ms": 2700, "ans": 1, "ok": true,  "pts": 22}
  ]'::JSONB
WHERE id = 'a3f0d282-50cb-4e50-ae9b-b12e77c4ccd7'::UUID
  AND user_id IS NULL;

-- 3. Authoritative 600-question picker across all 6 categories & 10 levels.
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

-- 4. Hardened Dynamic Trophy Matchmaking (Zero-Trust auth + 600 questions)
CREATE OR REPLACE FUNCTION public.find_or_create_match(
  p_user_id UUID,
  p_app_version TEXT DEFAULT '1.0.13',
  p_trophies INT DEFAULT 1000,
  p_last_opponent_id UUID DEFAULT NULL
)
RETURNS TABLE(match_id UUID, player1_id UUID, player2_id UUID, seed BIGINT, question_ids TEXT[])
LANGUAGE plpgsql
SECURITY DEFINER
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

  -- Authoritative server trophy read
  SELECT COALESCE(
    (SELECT lb.trophies FROM public.leaderboard AS lb WHERE lb.user_id = p_user_id LIMIT 1),
    p_trophies,
    1000
  ) INTO v_self_trophies;

  -- A. Clean stale queue rows (heartbeat window: 15 seconds)
  DELETE FROM public.matchmaking_queue AS q
  WHERE q.updated_at < NOW() - INTERVAL '15 seconds';

  -- B. Close any previous unfinished public matches for this user
  UPDATE public.matches AS m
  SET status = 'finished'
  WHERE (m.player1_id = p_user_id OR m.player2_id = p_user_id)
    AND m.status NOT IN ('finished', 'cancelled')
    AND m.is_private = FALSE;

  -- C. Priority 1: Dynamic expanding trophy bracket
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

  -- Priority 2: Fallback after 8s wait
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

  -- D. If opponent found, create matched game atomically
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
      player1_id,
      player2_id,
      seed,
      status,
      question_ids,
      current_question,
      is_private,
      is_ghost_match,
      created_at
    )
    VALUES (
      v_opponent_id,
      p_user_id,
      v_seed,
      'matched',
      v_question_ids,
      0,
      FALSE,
      FALSE,
      NOW()
    )
    RETURNING id INTO v_match_id;

    INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score, current_question_index)
    VALUES
      (v_match_id, v_opponent_id, FALSE, 0, 0),
      (v_match_id, p_user_id, FALSE, 0, 0);

    RETURN QUERY SELECT v_match_id, v_opponent_id, p_user_id, v_seed, v_question_ids;
  ELSE
    -- E. Register/update self in queue
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

-- 5. Hardened Private Room Creation (auth check + 600 questions)
CREATE OR REPLACE FUNCTION public.create_private_room(p_host_id UUID)
RETURNS TABLE(match_id UUID, room_code VARCHAR, expires_at TIMESTAMPTZ, seed BIGINT, question_ids TEXT[])
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
  IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_host_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  UPDATE public.matches AS m
  SET status = 'cancelled'
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
    player1_id,
    seed,
    question_ids,
    status,
    is_private,
    is_ghost_match,
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
    FALSE,
    v_code,
    v_expires,
    NOW()
  )
  RETURNING id INTO v_match_id;

  INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score)
  VALUES (v_match_id, p_host_id, TRUE, 0);

  RETURN QUERY SELECT v_match_id, v_code, v_expires, v_seed, v_questions;
END;
$$;

-- 6. Hardened Instant Rematch Creation (auth check + 600 questions)
CREATE OR REPLACE FUNCTION public.create_instant_rematch(
  p_parent_match_id UUID,
  p_user_id UUID
)
RETURNS TABLE(match_id UUID, player1_id UUID, player2_id UUID, seed BIGINT, question_ids TEXT[], is_friendly BOOLEAN)
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
  IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

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
    parent_match_id,
    player1_id,
    player2_id,
    seed,
    question_ids,
    status,
    is_ghost_match,
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
    FALSE,
    v_rematch_count,
    NOW()
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

-- 7. Idempotent Anti-Cheat submit_answer (prevents duplicate index scoring)
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

-- 8. Self-Feeding Ghost Recording Saver (GH-01 fixed: checks mp.finished_at,
--    allows human participants even in ghost duels, soft-archives beyond 5 active)
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

-- 9. Race-Safe, Non-Hijacking Auto-Ghost Matchmaker
--    Drop old signature cleanly because return columns now include is_human_match
DROP FUNCTION IF EXISTS public.find_or_create_ghost_match(UUID, INT);

CREATE FUNCTION public.find_or_create_ghost_match(
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

  -- A. Remove self from matchmaking queue first to minimize human race window
  DELETE FROM public.matchmaking_queue AS q WHERE q.user_id = p_user_id;

  -- B. Last-millisecond race guard: did a human just match us into a live game?
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

  -- C. Authoritative server trophies & clean previous unfinished public matches
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

  -- D. Server-Side Daily Cap Check (count only matches where user was live player1)
  SELECT COUNT(DISTINCT m.id)
  INTO v_daily_count
  FROM public.matches AS m
  WHERE m.player1_id = p_user_id
    AND m.is_ghost_match = TRUE
    AND m.created_at >= CURRENT_DATE::TIMESTAMPTZ;

  IF v_daily_count >= 15 THEN
    v_is_friendly := TRUE;
  END IF;

  -- E. Prefer active real-human ghosts matching trophy bracket outside 2h cooldown
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

  -- Fallback ignoring 2h cooldown
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

  -- F. Insert Ghost Match with player2_id = NULL & ONLY caller in match_participants
  --    so the recorded user is NEVER hijacked by Realtime or penalized by daily cap!
  INSERT INTO public.matches (
    player1_id,
    player2_id,
    seed,
    status,
    question_ids,
    current_question,
    is_private,
    is_ghost_match,
    source_ghost_recording_id,
    is_friendly,
    ghost_score,
    created_at
  )
  VALUES (
    p_user_id,
    NULL,
    v_ghost.seed,
    'matched',
    v_ghost.question_ids,
    0,
    FALSE,
    TRUE,
    v_ghost.id,
    v_is_friendly,
    COALESCE(v_ghost.total_score, 0),
    NOW()
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

-- 10. Hardened finish_match (adds auth.uid() guard & explicit table aliases)
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

GRANT EXECUTE ON FUNCTION public.generate_match_question_ids() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.find_or_create_match(UUID, TEXT, INT, UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.create_private_room(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.create_instant_rematch(UUID, UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.submit_answer(UUID, UUID, INT, BOOLEAN, INT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.save_ghost_timeline(UUID, UUID, JSONB) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.find_or_create_ghost_match(UUID, INT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.finish_match(UUID, UUID) TO authenticated, anon;

NOTIFY pgrst, 'reload schema';

