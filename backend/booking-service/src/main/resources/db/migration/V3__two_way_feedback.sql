-- Two-way feedback fields for bookings
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS expert_to_candidate_rating INTEGER,
  ADD COLUMN IF NOT EXISTS expert_to_candidate_comment TEXT,
  ADD COLUMN IF NOT EXISTS candidate_to_expert_rating INTEGER,
  ADD COLUMN IF NOT EXISTS candidate_to_expert_comment TEXT;

-- Backfill expert->candidate from legacy columns when present
UPDATE bookings
SET
  expert_to_candidate_rating = COALESCE(expert_to_candidate_rating, expert_rating),
  expert_to_candidate_comment = COALESCE(expert_to_candidate_comment, expert_comment)
WHERE (expert_rating IS NOT NULL OR expert_comment IS NOT NULL);

-- Range checks
ALTER TABLE bookings
  DROP CONSTRAINT IF EXISTS bookings_expert_to_candidate_rating_check;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_expert_to_candidate_rating_check
  CHECK (expert_to_candidate_rating IS NULL OR (expert_to_candidate_rating >= 1 AND expert_to_candidate_rating <= 5));

ALTER TABLE bookings
  DROP CONSTRAINT IF EXISTS bookings_candidate_to_expert_rating_check;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_candidate_to_expert_rating_check
  CHECK (candidate_to_expert_rating IS NULL OR (candidate_to_expert_rating >= 1 AND candidate_to_expert_rating <= 5));
