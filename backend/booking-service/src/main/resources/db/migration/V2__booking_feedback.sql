-- Add expert feedback fields to bookings
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS expert_rating INTEGER,
  ADD COLUMN IF NOT EXISTS expert_comment TEXT;

-- Keep rating in a reasonable range if present
ALTER TABLE bookings
  DROP CONSTRAINT IF EXISTS bookings_expert_rating_check;

ALTER TABLE bookings
  ADD CONSTRAINT bookings_expert_rating_check
  CHECK (expert_rating IS NULL OR (expert_rating >= 1 AND expert_rating <= 5));

