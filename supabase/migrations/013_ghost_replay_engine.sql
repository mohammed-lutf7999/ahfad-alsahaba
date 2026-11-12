-- ==============================================================================
-- 🚀 MIGRATION 013: GHOST REPLAY ENGINE & CHIVALRIC PLAYBACK (MILESTONE 4)
-- ==============================================================================
-- 1. Create public.ghost_recordings table:
--    - Holds human match timelines in compact JSONB format:
--      [{"q": 0, "ms": 3420, "ans": 2, "ok": true}, ...]
--    - Enforces Hygiene Filter: 5 questions, ms >= 600, score > 0.
-- 2. Add ghost columns to public.matches:
--    - is_ghost_match BOOLEAN DEFAULT FALSE
--    - source_ghost_recording_id UUID REFERENCES public.ghost_recordings(id)
-- 3. RPC: save_ghost_timeline:
--    - Validates human match completion and hygiene before saving.
-- 4. RPC: find_or_create_ghost_match:
--    - Strict Question Binding: Reuses EXACT seed and question_ids.
--    - Excludes self ghosts and recently encountered ghosts.
--    - Server-side daily cap: 15 competitive ghost matches per day;
--      subsequent matches become is_friendly = TRUE (0 trophies).
-- 5. Seed initial realistic Andalusian chivalric ghosts.
-- ==============================================================================

-- 1. GHOST RECORDINGS TABLE & MATCHES COLUMNS
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

CREATE INDEX IF NOT EXISTS idx_ghost_trophies 
ON public.ghost_recordings(trophies, created_at);

CREATE INDEX IF NOT EXISTS idx_ghost_user 
ON public.ghost_recordings(user_id);

-- Enable Row Level Security (Access is mediated exclusively via SECURITY DEFINER RPCs)
ALTER TABLE public.ghost_recordings ENABLE ROW LEVEL SECURITY;

-- Unique index to prevent duplicate recordings for same match and user
CREATE UNIQUE INDEX IF NOT EXISTS idx_ghost_unique_match_user 
ON public.ghost_recordings(source_match_id, user_id) 
WHERE source_match_id IS NOT NULL AND user_id IS NOT NULL;

-- Alter matches table to support ghost matches & friendly flag
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS is_ghost_match BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_friendly BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS ghost_score INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS source_ghost_recording_id UUID REFERENCES public.ghost_recordings(id);

CREATE INDEX IF NOT EXISTS idx_matches_ghost 
ON public.matches(is_ghost_match) 
WHERE is_ghost_match = TRUE;

-- 2. RPC: save_ghost_timeline (Hygiene Filter & Compact Recording)
CREATE OR REPLACE FUNCTION public.save_ghost_timeline(
  p_match_id UUID,
  p_user_id UUID,
  p_timeline JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
#variable_conflict use_column
DECLARE
  v_match RECORD;
  v_participant RECORD;
  v_user_profile RECORD;
  v_q_count INT;
  v_item JSONB;
  v_ms INT;
  v_lb RECORD;
BEGIN
  -- A. Hygiene Check 1: Timeline must be a JSON array of exactly 5 questions
  IF p_timeline IS NULL OR jsonb_typeof(p_timeline) != 'array' THEN
    RETURN FALSE;
  END IF;

  v_q_count := jsonb_array_length(p_timeline);
  IF v_q_count != 5 THEN
    RETURN FALSE;
  END IF;

  -- B. Hygiene Check 2: Each question response must be >= 600ms (prevent bots/spammers)
  FOR i IN 0..4 LOOP
    v_item := p_timeline->i;
    v_ms := COALESCE((v_item->>'ms')::INT, 0);
    IF v_ms < 600 THEN
      RETURN FALSE; -- Discard suspicious fast answers
    END IF;
  END LOOP;

  -- C. Verify Match and Participant
  SELECT m.id, m.seed, m.question_ids, m.is_private, m.is_ghost_match
  INTO v_match
  FROM public.matches AS m
  WHERE m.id = p_match_id AND m.status = 'finished';

  IF NOT FOUND OR v_match.is_ghost_match = TRUE THEN
    RETURN FALSE; -- Do not record ghosts from ghost matches
  END IF;

  SELECT mp.current_score, mp.current_question_index
  INTO v_participant
  FROM public.match_participants AS mp
  WHERE mp.match_id = p_match_id AND mp.user_id = p_user_id;

  -- Hygiene Check 3: Score must be > 0 and answered all questions
  IF NOT FOUND OR COALESCE(v_participant.current_score, 0) <= 0 THEN
    RETURN FALSE;
  END IF;

  -- D. Fetch player metadata
  SELECT COALESCE(up.display_name, 'فارس مجهول') AS display_name,
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

  -- E. Insert clean ghost recording
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
    NOW()
  )
  ON CONFLICT (source_match_id, user_id) WHERE source_match_id IS NOT NULL AND user_id IS NOT NULL DO NOTHING;

  RETURN TRUE;
END;
$function$;

-- 3. RPC: find_or_create_ghost_match (Strict Binding & Daily Cap)
CREATE OR REPLACE FUNCTION public.find_or_create_ghost_match(
  p_user_id UUID,
  p_trophies INTEGER DEFAULT 1000
)
RETURNS TABLE (
  match_id UUID,
  ghost_user_id UUID,
  ghost_name TEXT,
  ghost_avatar_index INTEGER,
  ghost_frame TEXT,
  ghost_level INTEGER,
  ghost_trophies INTEGER,
  seed BIGINT,
  question_ids TEXT[],
  timeline JSONB,
  is_friendly BOOLEAN,
  daily_ghost_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
#variable_conflict use_column
DECLARE
  v_daily_count INT := 0;
  v_is_friendly BOOLEAN := FALSE;
  v_ghost RECORD;
  v_new_match_id UUID;
  v_self_trophies INT := COALESCE(p_trophies, 1000);
BEGIN
  -- A. Server-Side Daily Cap Check (Max 15 ranked ghost matches per calendar day)
  SELECT COUNT(DISTINCT m.id)
  INTO v_daily_count
  FROM public.matches AS m
  JOIN public.match_participants AS mp ON mp.match_id = m.id
  WHERE mp.user_id = p_user_id
    AND m.is_ghost_match = TRUE
    AND m.created_at >= CURRENT_DATE::TIMESTAMPTZ;

  IF v_daily_count >= 15 THEN
    v_is_friendly := TRUE; -- Beyond 15, friendly match (no trophy inflation)
  END IF;

  -- B. Search for best ghost recording with Strict Binding
  -- Exclude:
  -- 1) Self ghosts (g.user_id != p_user_id)
  -- 2) Ghosts encountered in the last 2 hours
  SELECT g.id, g.user_id, g.display_name, g.avatar_index, g.equipped_frame,
         g.player_level, g.trophies, g.seed, g.question_ids, g.timeline, g.total_score
  INTO v_ghost
  FROM public.ghost_recordings AS g
  WHERE (g.user_id IS NULL OR g.user_id != p_user_id)
    AND g.id NOT IN (
      SELECT COALESCE(m.source_ghost_recording_id, '00000000-0000-0000-0000-000000000000'::UUID)
      FROM public.matches AS m
      JOIN public.match_participants AS mp ON mp.match_id = m.id
      WHERE mp.user_id = p_user_id
        AND m.is_ghost_match = TRUE
        AND m.created_at > NOW() - INTERVAL '2 hours'
    )
  ORDER BY 
    ABS(g.trophies - v_self_trophies) ASC,
    g.use_count ASC,
    RANDOM()
  LIMIT 1;

  -- Fallback if no recent ghost (allow any available ghost except self)
  IF v_ghost.id IS NULL THEN
    SELECT g.id, g.user_id, g.display_name, g.avatar_index, g.equipped_frame,
           g.player_level, g.trophies, g.seed, g.question_ids, g.timeline, g.total_score
    INTO v_ghost
    FROM public.ghost_recordings AS g
    WHERE (g.user_id IS NULL OR g.user_id != p_user_id)
    ORDER BY g.use_count ASC, RANDOM()
    LIMIT 1;
  END IF;

  IF v_ghost.id IS NULL THEN
    RAISE EXCEPTION 'لا توجد تسجيلات أشباح متوفرة حالياً';
  END IF;

  -- Increment use count
  UPDATE public.ghost_recordings
  SET use_count = use_count + 1
  WHERE id = v_ghost.id;

  -- C. Create Match with STRICT QUESTION & SEED BINDING
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
    CASE 
      WHEN v_ghost.user_id IS NOT NULL AND EXISTS(SELECT 1 FROM auth.users WHERE id = v_ghost.user_id) 
      THEN v_ghost.user_id 
      ELSE NULL 
    END,
    v_ghost.seed, -- STRICT: EXACT SEED FROM GHOST
    'matched',
    v_ghost.question_ids, -- STRICT: EXACT QUESTIONS FROM GHOST
    0,
    FALSE,
    TRUE,
    v_ghost.id,
    v_is_friendly,
    COALESCE(v_ghost.total_score, 0),
    NOW()
  )
  RETURNING id INTO v_new_match_id;

  -- Insert participants
  INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score, current_question_index)
  VALUES (v_new_match_id, p_user_id, TRUE, 0, 0);

  -- If ghost user exists in auth.users, add as second participant
  IF v_ghost.user_id IS NOT NULL AND EXISTS(SELECT 1 FROM auth.users WHERE id = v_ghost.user_id) THEN
    INSERT INTO public.match_participants (match_id, user_id, is_ready, current_score, current_question_index)
    VALUES (v_new_match_id, v_ghost.user_id, TRUE, COALESCE(v_ghost.total_score, 0), 5);
  END IF;

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
    v_daily_count;
END;
$function$;

-- 4. UPDATE finish_match TO RESPECT GHOST CAP (is_friendly)
-- If match is marked is_friendly, zero out trophies_delta
CREATE OR REPLACE FUNCTION public.finish_match(p_match_id uuid, p_user_id uuid)
 RETURNS TABLE(winner_user_id uuid, my_final_score integer, opponent_final_score integer, trophies_delta integer, my_total_trophies integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
    DELETE FROM public.matchmaking_queue WHERE user_id = p_user_id;

    -- Check if match is friendly or ghost
    SELECT COALESCE(is_friendly, FALSE), COALESCE(is_ghost_match, FALSE)
    INTO v_is_friendly, v_is_ghost
    FROM public.matches
    WHERE id = p_match_id;

    SELECT finished_at, COALESCE(current_score, 0)
    INTO v_prev_finished_at, v_my_score
    FROM public.match_participants
    WHERE match_id = p_match_id AND user_id = p_user_id;

    UPDATE public.match_participants
    SET finished_at = COALESCE(finished_at, NOW())
    WHERE match_id = p_match_id AND user_id = p_user_id
    RETURNING COALESCE(current_score, 0) INTO v_my_score;

    IF v_is_ghost THEN
        -- Resolve real ghost score from matches.ghost_score and ghost_recordings.total_score
        SELECT 
            COALESCE(m.ghost_score, 0),
            COALESCE(gr.total_score, 0)
        INTO v_opp_score, v_ghost_score
        FROM public.matches m
        LEFT JOIN public.ghost_recordings gr ON gr.id = m.source_ghost_recording_id
        WHERE m.id = p_match_id;

        v_opp_score := GREATEST(COALESCE(v_opp_score, 0), COALESCE(v_ghost_score, 0));
        v_opp_id := NULL;

        -- Update ghost participant record if present
        UPDATE public.match_participants
        SET current_score = v_opp_score, finished_at = COALESCE(finished_at, NOW())
        WHERE match_id = p_match_id AND user_id != p_user_id;
    ELSE
        SELECT user_id, COALESCE(current_score, 0)
        INTO v_opp_id, v_opp_score
        FROM public.match_participants
        WHERE match_id = p_match_id AND user_id != p_user_id
        LIMIT 1;
    END IF;

    SELECT COALESCE(up.win_streak, 0) INTO v_cur_streak
    FROM public.user_progress up
    WHERE up.user_id = p_user_id
    LIMIT 1;
    v_cur_streak := COALESCE(v_cur_streak, 0);

    SELECT COALESCE(lb.trophies, 1000) INTO v_cur_trophies
    FROM public.leaderboard lb
    WHERE lb.user_id = p_user_id
    LIMIT 1;
    v_cur_trophies := COALESCE(v_cur_trophies, 1000);

    IF v_my_score > COALESCE(v_opp_score, 0) THEN
        v_the_winner := p_user_id;
        v_new_streak := v_cur_streak + 1;
        v_trophies_delta := 25 + LEAST(v_new_streak * 2, 10);
    ELSIF COALESCE(v_opp_score, 0) > v_my_score THEN
        IF v_opp_id IS NOT NULL AND EXISTS(SELECT 1 FROM auth.users WHERE id = v_opp_id) THEN
            v_the_winner := v_opp_id;
        ELSE
            v_the_winner := NULL;
        END IF;

        IF v_is_friendly = TRUE THEN
            -- Friendly match: preserve win streak, zero trophies delta, PRESERVE shield (do not consume)
            v_new_streak := v_cur_streak;
            v_trophies_delta := 0;
        ELSIF v_prev_finished_at IS NULL AND EXISTS (
            SELECT 1 FROM public.user_inventory
            WHERE user_id = p_user_id AND item_id = 'powerup_shield'
        ) THEN
            DELETE FROM public.user_inventory
            WHERE user_id = p_user_id AND item_id = 'powerup_shield';
            v_new_streak := v_cur_streak;
            v_trophies_delta := 0;
        ELSE
            v_new_streak := 0;
            v_trophies_delta := -12;
        END IF;
    ELSE
        v_the_winner := NULL; -- Draw
        v_new_streak := v_cur_streak;
        v_trophies_delta := 5;
    END IF;

    -- Zero out trophies and preserve streak if friendly match
    IF v_is_friendly = TRUE THEN
        v_trophies_delta := 0;
        v_new_streak := v_cur_streak;
    END IF;

    UPDATE public.matches
    SET status = 'finished', winner_id = v_the_winner
    WHERE id = p_match_id;

    IF v_prev_finished_at IS NULL THEN
        v_xp_to_add := COALESCE(v_my_score, 0);
        IF v_xp_to_add > 0 AND EXISTS (
            SELECT 1 FROM public.user_inventory
            WHERE user_id = p_user_id AND item_id = 'powerup_xp_banner'
        ) THEN
            DELETE FROM public.user_inventory
            WHERE user_id = p_user_id AND item_id = 'powerup_xp_banner';
            v_xp_to_add := v_xp_to_add * 2;
        END IF;

        SELECT COALESCE(
            (SELECT up.display_name FROM public.user_progress up WHERE up.user_id = p_user_id LIMIT 1),
            (SELECT lb.display_name FROM public.leaderboard lb WHERE lb.user_id = p_user_id LIMIT 1),
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

        UPDATE public.user_progress
        SET 
            total_score = COALESCE(total_score, 0) + v_xp_to_add,
            high_score = GREATEST(COALESCE(high_score, 0), v_xp_to_add),
            coins = COALESCE(coins, 100) + v_match_coins,
            win_streak = v_new_streak,
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
$function$;

-- 5. SEED INITIAL REALISTIC CHIVALRIC GHOSTS
-- Insert 5 diverse baseline ghosts so the engine is immediately functional
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
  use_count
)
SELECT 
  gen_random_uuid(),
  NULL,
  'سيف اليرموك',
  2,
  'frame_bronze',
  14,
  1120,
  179401,
  ARRAY['quran:1:1', 'hadith:1:2', 'fiqh:1:0', 'seerah:1:3', 'aqeedah:1:1'],
  '[
    {"q": 0, "ms": 2850, "ans": 1, "ok": true},
    {"q": 1, "ms": 4120, "ans": 0, "ok": true},
    {"q": 2, "ms": 3200, "ans": 2, "ok": false},
    {"q": 3, "ms": 2100, "ans": 3, "ok": true},
    {"q": 4, "ms": 5300, "ans": 1, "ok": true}
  ]'::jsonb,
  68,
  0
WHERE NOT EXISTS (SELECT 1 FROM public.ghost_recordings WHERE display_name = 'سيف اليرموك');

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
  use_count
)
SELECT 
  gen_random_uuid(),
  NULL,
  'فارس القادسية',
  4,
  'frame_silver',
  22,
  1340,
  179402,
  ARRAY['quran:1:4', 'hadith:1:5', 'fiqh:1:3', 'seerah:1:1', 'aqeedah:1:6'],
  '[
    {"q": 0, "ms": 1950, "ans": 0, "ok": true},
    {"q": 1, "ms": 3400, "ans": 2, "ok": true},
    {"q": 2, "ms": 2800, "ans": 1, "ok": true},
    {"q": 3, "ms": 4600, "ans": 0, "ok": true},
    {"q": 4, "ms": 3100, "ans": 2, "ok": true}
  ]'::jsonb,
  95,
  0
WHERE NOT EXISTS (SELECT 1 FROM public.ghost_recordings WHERE display_name = 'فارس القادسية');

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
  use_count
)
SELECT 
  gen_random_uuid(),
  NULL,
  'درع حطين',
  1,
  'frame_gold',
  35,
  1520,
  179403,
  ARRAY['quran:1:2', 'hadith:1:1', 'fiqh:1:4', 'seerah:1:5', 'aqeedah:1:0'],
  '[
    {"q": 0, "ms": 2100, "ans": 3, "ok": true},
    {"q": 1, "ms": 2900, "ans": 1, "ok": true},
    {"q": 2, "ms": 3800, "ans": 0, "ok": false},
    {"q": 3, "ms": 1800, "ans": 2, "ok": true},
    {"q": 4, "ms": 2700, "ans": 1, "ok": true}
  ]'::jsonb,
  82,
  0
WHERE NOT EXISTS (SELECT 1 FROM public.ghost_recordings WHERE display_name = 'درع حطين');
