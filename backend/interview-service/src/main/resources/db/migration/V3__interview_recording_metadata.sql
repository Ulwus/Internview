ALTER TABLE interview_sessions
  ADD COLUMN IF NOT EXISTS recording_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS duration_seconds BIGINT,
  ADD COLUMN IF NOT EXISTS recorded_video_url VARCHAR(1024);
