-- Leaderboard Table for Global Rankings
-- Run this SQL in Supabase Dashboard > SQL Editor

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

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_leaderboard_score ON public.leaderboard(score DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_user_id ON public.leaderboard(user_id);

-- Enable Row Level Security
ALTER TABLE public.leaderboard ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read the leaderboard
CREATE POLICY "Anyone can view leaderboard" ON public.leaderboard
    FOR SELECT USING (true);

-- Policy: Authenticated users can insert their own records
CREATE POLICY "Users can insert own score" ON public.leaderboard
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own records
CREATE POLICY "Users can update own score" ON public.leaderboard
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own records
CREATE POLICY "Users can delete own score" ON public.leaderboard
    FOR DELETE USING (auth.uid() = user_id);
