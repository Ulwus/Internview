package io.internview.interview_service.events;

import java.time.Instant;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class InterviewEventsPublisher {

	private static final String EVENT_TYPE = "INTERVIEW_COMPLETED";

	private final KafkaTemplate<String, Object> kafkaTemplate;

	@Value("${internview.kafka.topics.interview-events}")
	private String interviewEventsTopic;

	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
	public void onInterviewCompleted(InterviewCompletedDomainEvent domainEvent) {
		InterviewCompletedEvent event = InterviewCompletedEvent.builder()
			.eventType(EVENT_TYPE)
			.eventId("evt-" + UUID.randomUUID())
			.timestamp(Instant.now())
			.payload(InterviewCompletedPayload.builder()
				.sessionId(domainEvent.sessionId())
				.bookingId(domainEvent.bookingId())
				.candidateId(domainEvent.candidateId())
				.expertId(domainEvent.expertId())
				.durationSeconds(domainEvent.durationSeconds())
				.recordedVideoUrl(domainEvent.recordedVideoUrl())
				.build())
			.build();

		this.kafkaTemplate.send(this.interviewEventsTopic, domainEvent.sessionId().toString(), event);
	}
}

