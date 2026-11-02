-- User Progress Table for Full Data Sync
-- Run this SQL in Supabase Dashboard > SQL Editor

-- Create table to store complete user progress
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

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_user_progress_user_id ON public.user_progress(user_id);

-- Enable Row Level Security
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view user progress (needed for Versus Screen)
CREATE POLICY "Anyone can view user progress" ON public.user_progress
    FOR SELECT USING (true);

-- Policy: Users can insert their own progress
CREATE POLICY "Users can insert own progress" ON public.user_progress
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own progress
CREATE POLICY "Users can update own progress" ON public.user_progress
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own progress
CREATE POLICY "Users can delete own progress" ON public.user_progress
    FOR DELETE USING (auth.uid() = user_id);
