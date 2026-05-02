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
public class BookingEventsPublisher {

	private static final String EVENT_TYPE = "BOOKING_CREATED";

	private final KafkaTemplate<String, Object> kafkaTemplate;

	@Value("${internview.kafka.topics.booking-events}")
	private String bookingEventsTopic;

	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
	public void onBookingCreated(BookingCreatedDomainEvent domainEvent) {
		BookingCreatedEvent event = BookingCreatedEvent.builder()
			.eventType(EVENT_TYPE)
			.eventId("evt-" + UUID.randomUUID())
			.timestamp(Instant.now())
			.payload(BookingCreatedPayload.builder()
				.bookingId(domainEvent.bookingId())
				.candidateId(domainEvent.candidateId())
				.expertId(domainEvent.expertId())
				.slotId(domainEvent.slotId())
				.scheduledTime(domainEvent.scheduledTime())
				.status(domainEvent.status())
				.build())
			.build();

		this.kafkaTemplate.send(this.bookingEventsTopic, domainEvent.bookingId().toString(), event);
	}
}

