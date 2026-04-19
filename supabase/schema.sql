-- ============================================================
-- PL.AI – Supabase Database Schema
-- Run this in Supabase SQL Editor (Database → SQL Editor → New Query)
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── USERS ────────────────────────────────────────────────────────────────────
-- Note: Supabase Auth manages the auth.users table automatically.
-- This table extends it with app-level metadata.

CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  onboarding_complete BOOLEAN DEFAULT FALSE,
  preferred_language TEXT DEFAULT 'en'
);

-- Trigger: auto-create users row on new Supabase Auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.users (id, email, phone)
  VALUES (NEW.id, NEW.email, NEW.phone)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─── ATHLETE PROFILES ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.athlete_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  gender TEXT CHECK (gender IN ('Male', 'Female', 'Other')),
  age INTEGER CHECK (age >= 13 AND age <= 80),
  weight_kg DECIMAL(5,2) CHECK (weight_kg >= 30 AND weight_kg <= 300),
  height_cm DECIMAL(5,1) CHECK (height_cm >= 100 AND height_cm <= 250),
  experience_level TEXT CHECK (experience_level IN ('Beginner', 'Intermediate', 'Advanced')),
  training_days_per_week INTEGER CHECK (training_days_per_week >= 2 AND training_days_per_week <= 5),
  goal TEXT CHECK (goal IN ('Strength', 'Bulk', 'Cut')),
  focus_lifts TEXT[] NOT NULL DEFAULT '{}',
  squat_max_kg DECIMAL(6,2),
  bench_max_kg DECIMAL(6,2),
  deadlift_max_kg DECIMAL(6,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER athlete_profiles_updated_at
  BEFORE UPDATE ON public.athlete_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── TRAINING PROGRAMS ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.training_programs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  week_number INTEGER NOT NULL CHECK (week_number > 0),
  block_type TEXT NOT NULL CHECK (block_type IN ('accumulation', 'intensification', 'peak', 'deload')),
  program_json JSONB NOT NULL,
  generated_at TIMESTAMPTZ DEFAULT NOW(),
  is_current BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_training_programs_user_id ON public.training_programs(user_id);
CREATE INDEX idx_training_programs_is_current ON public.training_programs(user_id, is_current);

-- ─── TRAINING SESSIONS ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.training_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  program_id UUID NOT NULL REFERENCES public.training_programs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  day_number INTEGER NOT NULL CHECK (day_number > 0),
  main_lift TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'locked'
    CHECK (status IN ('locked', 'available', 'in_progress', 'completed')),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

CREATE INDEX idx_training_sessions_user_id ON public.training_sessions(user_id);
CREATE INDEX idx_training_sessions_program_id ON public.training_sessions(program_id);

-- ─── SESSION EXERCISES ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.session_exercises (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES public.training_sessions(id) ON DELETE CASCADE,
  exercise_name TEXT NOT NULL,
  programmed_sets INTEGER NOT NULL CHECK (programmed_sets > 0),
  programmed_reps INTEGER NOT NULL CHECK (programmed_reps > 0),
  programmed_weight_kg DECIMAL(6,2) NOT NULL CHECK (programmed_weight_kg >= 0),
  rpe_target INTEGER CHECK (rpe_target >= 1 AND rpe_target <= 11),
  notes TEXT,
  order_index INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_session_exercises_session_id ON public.session_exercises(session_id);

-- ─── SET LOGS ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.set_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exercise_id UUID NOT NULL REFERENCES public.session_exercises(id) ON DELETE CASCADE,
  set_number INTEGER NOT NULL CHECK (set_number > 0),
  actual_weight_kg DECIMAL(6,2) NOT NULL CHECK (actual_weight_kg >= 0),
  actual_reps INTEGER NOT NULL CHECK (actual_reps >= 0),
  rpe_actual INTEGER NOT NULL CHECK (rpe_actual >= 1 AND rpe_actual <= 11),
  logged_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_set_logs_exercise_id ON public.set_logs(exercise_id);

-- ─── CHAT MESSAGES ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  flagged_injury BOOLEAN DEFAULT FALSE,
  flagged_exercise_swap BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_chat_messages_user_id ON public.chat_messages(user_id);
CREATE INDEX idx_chat_messages_created_at ON public.chat_messages(user_id, created_at);
