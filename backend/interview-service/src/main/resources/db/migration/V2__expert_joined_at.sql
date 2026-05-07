ALTER TABLE interview_sessions
  ADD COLUMN IF NOT EXISTS expert_joined_at TIMESTAMPTZ;

