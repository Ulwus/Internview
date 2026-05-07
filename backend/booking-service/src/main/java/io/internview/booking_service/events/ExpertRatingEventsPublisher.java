package io.internview.booking_service.events;

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
public class ExpertRatingEventsPublisher {

	private static final String EVENT_TYPE = "EXPERT_RATING_UPDATED";

	private final KafkaTemplate<String, Object> kafkaTemplate;

	@Value("${internview.kafka.topics.expert-rating-events}")
	private String expertRatingEventsTopic;

	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
	public void onExpertRatingUpdated(ExpertRatingUpdatedDomainEvent domainEvent) {
		ExpertRatingUpdatedEvent event = ExpertRatingUpdatedEvent.builder()
			.eventType(EVENT_TYPE)
			.eventId("evt-" + UUID.randomUUID())
			.timestamp(Instant.now())
			.payload(ExpertRatingUpdatedPayload.builder()
				.expertUserId(domainEvent.expertUserId())
				.averageRating(domainEvent.averageRating())
				.totalRated(domainEvent.totalRated())
				.build())
			.build();

		this.kafkaTemplate.send(this.expertRatingEventsTopic, domainEvent.expertUserId().toString(), event);
	}
}

