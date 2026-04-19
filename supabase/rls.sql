-- ============================================================
-- PL.AI – Row Level Security (RLS) Policies
-- Run AFTER schema.sql
-- Users can only read/write their own data (PRD §13)
-- ============================================================

-- ─── Enable RLS on all tables ────────────────────────────────────────────────

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.athlete_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.set_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- ─── USERS ────────────────────────────────────────────────────────────────────

CREATE POLICY "Users: select own row"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users: update own row"
  ON public.users FOR UPDATE
  USING (auth.uid() = id);

-- Service role can always insert (used by auth trigger)
CREATE POLICY "Users: insert via service"
  ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- ─── ATHLETE PROFILES ─────────────────────────────────────────────────────────

CREATE POLICY "AthleteProfiles: select own"
  ON public.athlete_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "AthleteProfiles: insert own"
  ON public.athlete_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "AthleteProfiles: update own"
  ON public.athlete_profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "AthleteProfiles: delete own"
  ON public.athlete_profiles FOR DELETE
  USING (auth.uid() = user_id);

-- ─── TRAINING PROGRAMS ────────────────────────────────────────────────────────

CREATE POLICY "TrainingPrograms: select own"
  ON public.training_programs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "TrainingPrograms: insert own"
  ON public.training_programs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "TrainingPrograms: update own"
  ON public.training_programs FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "TrainingPrograms: delete own"
  ON public.training_programs FOR DELETE
  USING (auth.uid() = user_id);

-- ─── TRAINING SESSIONS ────────────────────────────────────────────────────────

CREATE POLICY "TrainingSessions: select own"
  ON public.training_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "TrainingSessions: insert own"
  ON public.training_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "TrainingSessions: update own"
  ON public.training_sessions FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "TrainingSessions: delete own"
  ON public.training_sessions FOR DELETE
  USING (auth.uid() = user_id);

-- ─── SESSION EXERCISES ────────────────────────────────────────────────────────
-- Access via join to training_sessions (user_id check)

CREATE POLICY "SessionExercises: select own"
  ON public.session_exercises FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.training_sessions ts
      WHERE ts.id = session_exercises.session_id
        AND ts.user_id = auth.uid()
    )
  );

CREATE POLICY "SessionExercises: insert own"
  ON public.session_exercises FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.training_sessions ts
      WHERE ts.id = session_exercises.session_id
        AND ts.user_id = auth.uid()
    )
  );

CREATE POLICY "SessionExercises: update own"
  ON public.session_exercises FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.training_sessions ts
      WHERE ts.id = session_exercises.session_id
        AND ts.user_id = auth.uid()
    )
  );

CREATE POLICY "SessionExercises: delete own"
  ON public.session_exercises FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.training_sessions ts
      WHERE ts.id = session_exercises.session_id
        AND ts.user_id = auth.uid()
    )
  );

-- ─── SET LOGS ─────────────────────────────────────────────────────────────────
-- Access via join to session_exercises → training_sessions (user_id check)

CREATE POLICY "SetLogs: select own"
  ON public.set_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.session_exercises se
      JOIN public.training_sessions ts ON ts.id = se.session_id
      WHERE se.id = set_logs.exercise_id
        AND ts.user_id = auth.uid()
    )
  );

CREATE POLICY "SetLogs: insert own"
  ON public.set_logs FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.session_exercises se
      JOIN public.training_sessions ts ON ts.id = se.session_id
      WHERE se.id = set_logs.exercise_id
        AND ts.user_id = auth.uid()
    )
  );

CREATE POLICY "SetLogs: update own"
  ON public.set_logs FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.session_exercises se
      JOIN public.training_sessions ts ON ts.id = se.session_id
      WHERE se.id = set_logs.exercise_id
        AND ts.user_id = auth.uid()
    )
  );

CREATE POLICY "SetLogs: delete own"
  ON public.set_logs FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.session_exercises se
      JOIN public.training_sessions ts ON ts.id = se.session_id
      WHERE se.id = set_logs.exercise_id
        AND ts.user_id = auth.uid()
    )
  );

-- ─── CHAT MESSAGES ────────────────────────────────────────────────────────────

CREATE POLICY "ChatMessages: select own"
  ON public.chat_messages FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "ChatMessages: insert own"
  ON public.chat_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "ChatMessages: delete own"
  ON public.chat_messages FOR DELETE
  USING (auth.uid() = user_id);

-- ─── SERVICE ROLE BYPASS ──────────────────────────────────────────────────────
-- The backend uses service_role_key which bypasses RLS.
-- This is intentional for server-side operations (program generation, chat sync).
-- NEVER expose the service role key to the iOS client.
