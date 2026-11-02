-- =====================================================================
-- ⚔️ مشروع معركة أحفاد الصحابة - سكريبت إنشاء قاعدة البيانات الشامل
-- مشروع Supabase: khatzzpqxaiwuoodgcst
-- انسخ هذا الكود بالكامل وضعه في: Supabase Dashboard > SQL Editor ثم اضغط RUN
-- =====================================================================

-- 1. جدول لوحة الصدارة العالمية (Leaderboard)
CREATE TABLE IF NOT EXISTS public.leaderboard (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    display_name TEXT NOT NULL DEFAULT 'لاعب',
    email TEXT,
    avatar_url TEXT,
    score INTEGER NOT NULL DEFAULT 0,
    country_code TEXT DEFAULT 'XX',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_score ON public.leaderboard(score DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_user_id ON public.leaderboard(user_id);

ALTER TABLE public.leaderboard ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view leaderboard" ON public.leaderboard;
CREATE POLICY "Anyone can view leaderboard" ON public.leaderboard FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert own score" ON public.leaderboard;
CREATE POLICY "Users can insert own score" ON public.leaderboard FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own score" ON public.leaderboard;
CREATE POLICY "Users can update own score" ON public.leaderboard FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own score" ON public.leaderboard;
CREATE POLICY "Users can delete own score" ON public.leaderboard FOR DELETE USING (auth.uid() = user_id);


-- 2. جدول تقدم المستخدم ومزامنة البيانات (User Progress)
CREATE TABLE IF NOT EXISTS public.user_progress (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    display_name TEXT NOT NULL DEFAULT 'لاعب',
    avatar_index INTEGER DEFAULT 0,
    total_score INTEGER NOT NULL DEFAULT 0,
    high_score INTEGER NOT NULL DEFAULT 0,
    category_progress JSONB DEFAULT '{}'::jsonb,
    level_stars JSONB DEFAULT '{}'::jsonb,
    level_scores JSONB DEFAULT '{}'::jsonb,
    achievement_progress JSONB DEFAULT '{}'::jsonb,
    current_streak INTEGER DEFAULT 0,
    total_days_played INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_progress_user_id ON public.user_progress(user_id);

ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view user progress" ON public.user_progress;
CREATE POLICY "Anyone can view user progress" ON public.user_progress FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert own progress" ON public.user_progress;
CREATE POLICY "Users can insert own progress" ON public.user_progress FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own progress" ON public.user_progress;
CREATE POLICY "Users can update own progress" ON public.user_progress FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own progress" ON public.user_progress;
CREATE POLICY "Users can delete own progress" ON public.user_progress FOR DELETE USING (auth.uid() = user_id);


-- 3. جداول ونظام اللعب الجماعي والتحدي الأونلاين (Multiplayer)
CREATE TABLE IF NOT EXISTS public.matchmaking_queue (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  app_version TEXT NOT NULL,
  score INT DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.matches (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  player1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  player2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status TEXT CHECK (status IN ('waiting', 'matched', 'ready', 'playing', 'finished')) DEFAULT 'waiting',
  winner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  seed BIGINT NOT NULL DEFAULT FLOOR(RANDOM() * 1000000),
  questions JSONB DEFAULT '[]'::jsonb,
  question_ids TEXT[],
  current_question INT DEFAULT 0,
  started_at TIMESTAMPTZ,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.match_participants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  match_id UUID REFERENCES public.matches(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  current_score INT DEFAULT 0,
  current_question_index INT DEFAULT 0,
  is_ready BOOLEAN DEFAULT FALSE,
  ready_at TIMESTAMPTZ,
  finished_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(match_id, user_id)
);

ALTER TABLE public.matchmaking_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert themselves" ON public.matchmaking_queue;
CREATE POLICY "Users can insert themselves" ON public.matchmaking_queue FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete themselves" ON public.matchmaking_queue;
CREATE POLICY "Users can delete themselves" ON public.matchmaking_queue FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update queue heartbeat" ON public.matchmaking_queue;
CREATE POLICY "Users can update queue heartbeat" ON public.matchmaking_queue FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can see their matches" ON public.matches;
CREATE POLICY "Users can see their matches" ON public.matches FOR SELECT USING (auth.uid() = player1_id OR auth.uid() = player2_id);

DROP POLICY IF EXISTS "System creates matches" ON public.matches;
CREATE POLICY "System creates matches" ON public.matches FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "System updates matches" ON public.matches;
CREATE POLICY "System updates matches" ON public.matches FOR UPDATE USING (auth.uid() = player1_id OR auth.uid() = player2_id);

DROP POLICY IF EXISTS "Users can see participants in their match" ON public.match_participants;
CREATE POLICY "Users can see participants in their match" ON public.match_participants FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.matches m 
    WHERE m.id = match_participants.match_id 
    AND (m.player1_id = auth.uid() OR m.player2_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "Users can update their own progress" ON public.match_participants;
CREATE POLICY "Users can update their own progress" ON public.match_participants FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert participant records" ON public.match_participants;
CREATE POLICY "Users can insert participant records" ON public.match_participants FOR INSERT WITH CHECK (true);

-- تفعيل ميزة البث المباشر الفوري (Realtime)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'matches'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'match_participants'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.match_participants;
  END IF;
END $$;


-- 4. دوال التوفيق والتحكيم للمباريات (Matchmaking Functions)
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
  SELECT user_id INTO v_opponent_id
  FROM public.matchmaking_queue
  WHERE user_id != p_user_id
  AND updated_at > NOW() - INTERVAL '30 seconds'
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_opponent_id IS NOT NULL THEN
    DELETE FROM public.matchmaking_queue WHERE user_id = v_opponent_id;
    v_seed := FLOOR(RANDOM() * 1000000);
    
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

    INSERT INTO public.match_participants (match_id, user_id) VALUES (v_match_id, v_opponent_id);
    INSERT INTO public.match_participants (match_id, user_id) VALUES (v_match_id, p_user_id);
    
    RETURN QUERY SELECT v_match_id, v_opponent_id, p_user_id, v_seed, '[]'::jsonb, 'waiting'::TEXT;
  ELSE
    INSERT INTO public.matchmaking_queue (user_id, app_version, updated_at)
    VALUES (p_user_id, p_app_version, NOW())
    ON CONFLICT (user_id) 
    DO UPDATE SET updated_at = NOW();
    
    RETURN;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION public.confirm_ready(p_match_id UUID, p_user_id UUID)
RETURNS TABLE (both_ready BOOLEAN, match_status TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  ready_count INT;
  current_status TEXT;
BEGIN
  UPDATE public.match_participants
  SET is_ready = TRUE, ready_at = NOW()
  WHERE match_id = p_match_id AND user_id = p_user_id;

  SELECT COUNT(*) INTO ready_count
  FROM public.match_participants
  WHERE match_id = p_match_id AND is_ready = TRUE;

  IF ready_count >= 2 THEN
    UPDATE public.matches
    SET status = 'playing', started_at = NOW()
    WHERE id = p_match_id;
    current_status := 'playing';
    both_ready := TRUE;
  ELSE
    SELECT status INTO current_status
    FROM public.matches
    WHERE id = p_match_id;
    both_ready := FALSE;
  END IF;

  RETURN QUERY SELECT both_ready, current_status;
END;
$$;

