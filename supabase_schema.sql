-- Supabase SQL Schema for PulseTrack
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/YOUR_PROJECT/sql

-- Enable RLS
ALTER DATABASE postgres SET "app.jwt_secret" TO 'your-jwt-secret';

-- ============================================================
-- PROFILES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  age INTEGER NOT NULL,
  weight DOUBLE PRECISION NOT NULL,
  height DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can only access their own profile
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own profile"
  ON public.profiles FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- PRESSURE READINGS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.pressure_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  local_id INTEGER,
  systolic INTEGER NOT NULL,
  diastolic INTEGER NOT NULL,
  pulse INTEGER NOT NULL,
  measured_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, local_id)
);

-- Enable RLS on pressure_readings
ALTER TABLE public.pressure_readings ENABLE ROW LEVEL SECURITY;

-- Users can only access their own readings
CREATE POLICY "Users can view own readings"
  ON public.pressure_readings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own readings"
  ON public.pressure_readings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own readings"
  ON public.pressure_readings FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own readings"
  ON public.pressure_readings FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_readings_user_id ON public.pressure_readings(user_id);
CREATE INDEX IF NOT EXISTS idx_readings_measured_at ON public.pressure_readings(measured_at DESC);
