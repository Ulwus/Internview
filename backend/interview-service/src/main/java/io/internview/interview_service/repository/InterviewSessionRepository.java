package io.internview.interview_service.repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import io.internview.interview_service.domain.InterviewSession;

public interface InterviewSessionRepository extends JpaRepository<InterviewSession, UUID> {
	Optional<InterviewSession> findByBookingId(UUID bookingId);

	/**
	 * Recording başlangıcını atomik şekilde claim eder.
	 * Yalnızca {@code recording_started_at IS NULL} ve status henüz {@code COMPLETED} değilse günceller.
	 *
	 * @return etkilenen satır sayısı; 1 ise bu çağrı tarafından claim edildi, 0 ise zaten başlatılmış / oturum bitmiş
	 */
	@Modifying
	@Transactional
	@Query("update InterviewSession s set s.recordingStartedAt = :startedAt"
		+ " where s.id = :sessionId"
		+ " and s.recordingStartedAt is null"
		+ " and s.status <> 'COMPLETED'")
	int tryClaimRecordingStart(@Param("sessionId") UUID sessionId, @Param("startedAt") Instant startedAt);

	/**
	 * Recording start claim'ini geri alır (örn. media-service start çağrısı patladığında).
	 */
	@Modifying
	@Transactional
	@Query("update InterviewSession s set s.recordingStartedAt = null"
		+ " where s.id = :sessionId and s.recordingStartedAt = :startedAt")
	int clearRecordingStartIfMatches(@Param("sessionId") UUID sessionId, @Param("startedAt") Instant startedAt);
}

