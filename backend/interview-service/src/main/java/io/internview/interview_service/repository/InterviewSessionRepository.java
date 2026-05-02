package io.internview.interview_service.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import io.internview.interview_service.domain.InterviewSession;

public interface InterviewSessionRepository extends JpaRepository<InterviewSession, UUID> {
	Optional<InterviewSession> findByBookingId(UUID bookingId);
}

