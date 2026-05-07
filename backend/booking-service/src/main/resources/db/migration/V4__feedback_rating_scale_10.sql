ALTER TABLE bookings
  DROP CONSTRAINT IF EXISTS bookings_expert_rating_check;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_expert_rating_check
  CHECK (expert_rating IS NULL OR (expert_rating >= 1 AND expert_rating <= 10));

ALTER TABLE bookings
  DROP CONSTRAINT IF EXISTS bookings_expert_to_candidate_rating_check;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_expert_to_candidate_rating_check
  CHECK (expert_to_candidate_rating IS NULL OR (expert_to_candidate_rating >= 1 AND expert_to_candidate_rating <= 10));

ALTER TABLE bookings
  DROP CONSTRAINT IF EXISTS bookings_candidate_to_expert_rating_check;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_candidate_to_expert_rating_check
  CHECK (candidate_to_expert_rating IS NULL OR (candidate_to_expert_rating >= 1 AND candidate_to_expert_rating <= 10));
