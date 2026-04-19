-- ============================================================
-- PL.AI – Development Seed Data (optional, for testing)
-- Run AFTER schema.sql and rls.sql
-- ============================================================

-- NOTE: In production, do NOT run seed data.
-- This is for local Supabase dev only.

-- Seed an athlete profile linked to a Supabase Auth user
-- Replace 'your-test-user-uuid' with an actual user UUID from auth.users

/*
INSERT INTO public.athlete_profiles (
  user_id,
  first_name,
  last_name,
  gender,
  age,
  weight_kg,
  height_cm,
  experience_level,
  training_days_per_week,
  goal,
  focus_lifts,
  squat_max_kg,
  bench_max_kg,
  deadlift_max_kg
) VALUES (
  'your-test-user-uuid',
  'Alex',
  'Johnson',
  'Male',
  28,
  85.0,
  178.0,
  'Intermediate',
  4,
  'Strength',
  ARRAY['Squat', 'Bench Press', 'Deadlift'],
  140.0,
  100.0,
  180.0
);
*/
