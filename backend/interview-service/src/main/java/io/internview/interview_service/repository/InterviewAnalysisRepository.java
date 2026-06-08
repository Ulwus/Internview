package io.internview.interview_service.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import io.internview.interview_service.domain.InterviewAnalysis;

public interface InterviewAnalysisRepository extends JpaRepository<InterviewAnalysis, UUID> {
	Optional<InterviewAnalysis> findBySessionId(UUID sessionId);
}
