CREATE TABLE IF NOT EXISTS interview_sessions (
  id UUID PRIMARY KEY,
  booking_id UUID NOT NULL UNIQUE,
  candidate_id UUID NOT NULL,
  expert_id UUID NOT NULL,
  scheduled_time TIMESTAMPTZ NOT NULL,
  status VARCHAR(32) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

