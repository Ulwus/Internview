package io.internview.interview_service.service;

import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import io.internview.interview_service.domain.InterviewSession;
import io.internview.interview_service.events.InterviewCompletedDomainEvent;
import io.internview.interview_service.kafka.BookingCreatedPayload;
import io.internview.interview_service.repository.InterviewSessionRepository;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class InterviewSessionService {

	private final InterviewSessionRepository repository;
	private final ApplicationEventPublisher eventPublisher;

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
		this.repository.save(session);
	}

	@Transactional(readOnly = true)
	public InterviewSession getByBookingForParticipant(UUID bookingId, UUID userId) {
		InterviewSession session = this.repository.findByBookingId(bookingId)
			.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Mülakat oturumu bulunamadı."));

		if (!session.getCandidateId().equals(userId) && !session.getExpertId().equals(userId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Bu oturuma erişim yetkiniz yok.");
		}
		return session;
	}

	@Transactional
	public InterviewSession completeByBookingId(UUID bookingId, long durationSeconds, String recordedVideoUrl) {
		InterviewSession session = this.repository.findByBookingId(bookingId)
			.orElseThrow(() -> new IllegalArgumentException("Görüşme oturumu bulunamadı: bookingId=" + bookingId));

		session.setStatus("COMPLETED");
		InterviewSession saved = this.repository.save(session);

		this.eventPublisher.publishEvent(new InterviewCompletedDomainEvent(
			saved.getId(),
			saved.getBookingId(),
			saved.getCandidateId(),
			saved.getExpertId(),
			durationSeconds,
			recordedVideoUrl
		));

		return saved;
	}
}

