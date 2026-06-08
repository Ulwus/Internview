CREATE TABLE IF NOT EXISTS interview_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL UNIQUE REFERENCES interview_sessions(id) ON DELETE CASCADE,
  transcript TEXT NOT NULL,
  analysis_result JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS interview_transcript_segments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES interview_sessions(id) ON DELETE CASCADE,
  segment_index INTEGER NOT NULL,
  start_second NUMERIC NOT NULL,
  end_second NUMERIC NOT NULL,
  transcript TEXT NOT NULL,
  analysis_result JSONB NOT NULL,
  recorded_video_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (session_id, segment_index)
);
