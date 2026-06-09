package io.internview.interview_service.service;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import io.internview.interview_service.domain.InterviewSession;
import io.internview.interview_service.events.InterviewCompletedDomainEvent;
import io.internview.interview_service.kafka.BookingCreatedPayload;
import io.internview.interview_service.media.MediaServiceClient;
import io.internview.interview_service.media.dto.MediaServiceDtos.RecordingStopResponse;
import io.internview.interview_service.repository.InterviewSessionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class InterviewSessionService {

	private static final String STATUS_COMPLETED = "COMPLETED";

	private final InterviewSessionRepository repository;
	private final ApplicationEventPublisher eventPublisher;
	private final MediaServiceClient mediaServiceClient;

	@Transactional
	public void ensureSessionForBookingCreated(BookingCreatedPayload payload) {
		if (payload == null || payload.getBookingId() == null) {
			return;
		}
		if (this.repository.findByBookingId(payload.getBookingId()).isPresent()) {
			return;
		}

		InterviewSession session = InterviewSession.builder()
			.bookingId(payload.getBookingId())
			.candidateId(payload.getCandidateId())
			.expertId(payload.getExpertId())
			.scheduledTime(payload.getScheduledTime())
			.status("SCHEDULED")
			.build();
		InterviewSession saved = this.repository.save(session);

		// Mediasoup room oluştur
		try {
			this.mediaServiceClient.createRoom(saved.getId().toString());
			log.info("Mediasoup room oluşturuldu: sessionId={}", saved.getId());
		}
		catch (Exception ex) {
			log.warn("Mediasoup room oluşturulamadı (daha sonra tekrar denenebilir): {}", ex.getMessage());
		}
	}

	@Transactional(readOnly = true)
	public InterviewSession getByBookingForParticipant(UUID bookingId, UUID userId) {
		InterviewSession session = this.repository.findByBookingId(bookingId)
			.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Mülakat oturumu bulunamadı."));

		this.ensureParticipant(session, userId);
		return session;
	}

	@Transactional(readOnly = true)
	public InterviewSession getByIdForParticipant(UUID sessionId, UUID userId) {
		InterviewSession session = this.repository.findById(sessionId)
			.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Mülakat oturumu bulunamadı."));

		this.ensureParticipant(session, userId);
		return session;
	}

	private void ensureParticipant(InterviewSession session, UUID userId) {
		if (!session.getCandidateId().equals(userId) && !session.getExpertId().equals(userId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Bu oturuma erişim yetkiniz yok.");
		}
	}

	@Transactional
	public InterviewSession completeByBookingId(UUID bookingId, long durationSeconds, String recordedVideoUrl) {
		InterviewSession session = this.repository.findByBookingId(bookingId)
			.orElseThrow(() -> new IllegalArgumentException("Görüşme oturumu bulunamadı: bookingId=" + bookingId));
		return this.completeInternal(session, durationSeconds, recordedVideoUrl);
	}

	/**
	 * Session ID ile tamamlama (WebSocket FINISH_DONE handshake'inden çağrılır).
	 * Süre, recording başlangıç zamanına göre türetilir; client'tan gelen değere güvenilmez.
	 */
	@Transactional
	public InterviewSession completeBySessionId(UUID sessionId) {
		InterviewSession session = this.repository.findById(sessionId)
			.orElseThrow(() -> new IllegalArgumentException("Görüşme oturumu bulunamadı: sessionId=" + sessionId));
		long derivedDuration = this.deriveDurationSeconds(session);
		return this.completeInternal(session, derivedDuration, null);
	}

	private InterviewSession completeInternal(InterviewSession session, long durationSeconds, String recordedVideoUrl) {
		// İdempotenttir: zaten COMPLETED ise no-op döner.
		if (STATUS_COMPLETED.equalsIgnoreCase(session.getStatus())) {
			log.debug("Session zaten COMPLETED, completion no-op: sessionId={}", session.getId());
			return session;
		}

		// Recording aktifse durdur ve S3 URL'sini al (best-effort).
		String finalVideoUrl = recordedVideoUrl;
		try {
			RecordingStopResponse recordingResponse = this.mediaServiceClient
				.stopRecording(session.getId().toString());
			if (recordingResponse != null && recordingResponse.getRecordedVideoUrl() != null) {
				finalVideoUrl = recordingResponse.getRecordedVideoUrl();
				log.info("Recording durduruldu, S3 URL: {}", finalVideoUrl);
			}
		}
		catch (Exception ex) {
			log.warn("Recording durdurma başarısız (muhtemelen aktif değildi): {}", ex.getMessage());
		}

		// Mediasoup room'u kapat (best-effort). Orphan recording güvenlik ağı:
		// closeRoom response'u recordedVideoUrl içeriyorsa onu kullan.
		try {
			String closeUrl = this.mediaServiceClient.closeRoom(session.getId().toString());
			if (finalVideoUrl == null && closeUrl != null) {
				finalVideoUrl = closeUrl;
				log.info("Room close sırasında recording yakalandı: {}", finalVideoUrl);
			}
		}
		catch (Exception ex) {
			log.warn("Mediasoup room kapatılamadı: {}", ex.getMessage());
		}

		long finalDuration = durationSeconds > 0 ? durationSeconds : this.deriveDurationSeconds(session);

		session.setStatus(STATUS_COMPLETED);
		session.setCompletedAt(Instant.now());
		session.setDurationSeconds(finalDuration);
		if (finalVideoUrl != null) {
			session.setRecordedVideoUrl(finalVideoUrl);
		}
		InterviewSession saved = this.repository.save(session);

		this.eventPublisher.publishEvent(new InterviewCompletedDomainEvent(
			saved.getId(),
			saved.getBookingId(),
			saved.getCandidateId(),
			saved.getExpertId(),
			finalDuration,
			finalVideoUrl
		));

		return saved;
	}

	private long deriveDurationSeconds(InterviewSession session) {
		Instant start = session.getRecordingStartedAt() != null
			? session.getRecordingStartedAt()
			: session.getExpertJoinedAt();
		if (start == null) {
			return 0L;
		}
		return Math.max(0L, Duration.between(start, Instant.now()).getSeconds());
	}
}
