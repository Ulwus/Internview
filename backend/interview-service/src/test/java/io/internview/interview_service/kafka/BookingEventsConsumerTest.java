package io.internview.interview_service.kafka;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.test.context.TestPropertySource;

import io.internview.interview_service.repository.InterviewSessionRepository;

@SpringBootTest
@EmbeddedKafka(partitions = 1, topics = { "booking-events" })
@TestPropertySource(properties = {
	"spring.kafka.bootstrap-servers=${spring.embedded.kafka.brokers}",
	"internview.kafka.topics.booking-events=booking-events",
	"spring.flyway.enabled=false",
	"spring.jpa.hibernate.ddl-auto=create-drop",
	"spring.datasource.url=jdbc:h2:mem:interview;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE",
	"spring.datasource.driver-class-name=org.h2.Driver",
	"spring.datasource.username=sa",
	"spring.datasource.password="
})
class BookingEventsConsumerTest {

	@Autowired
	private KafkaTemplate<String, Object> kafkaTemplate;

	@Autowired
	private InterviewSessionRepository sessionRepository;

	@Test
	void createsSessionFromBookingCreatedEvent() throws Exception {
		UUID bookingId = UUID.randomUUID();

		BookingCreatedPayload payload = new BookingCreatedPayload();
		payload.setBookingId(bookingId);
		payload.setCandidateId(UUID.randomUUID());
		payload.setExpertId(UUID.randomUUID());
		payload.setSlotId(UUID.randomUUID());
		payload.setScheduledTime(Instant.now());
		payload.setStatus("CONFIRMED");

		BookingCreatedEventMessage msg = new BookingCreatedEventMessage();
		msg.setEventType("BOOKING_CREATED");
		msg.setEventId("evt-" + UUID.randomUUID());
		msg.setTimestamp(Instant.now());
		msg.setPayload(payload);

		this.kafkaTemplate.send("booking-events", bookingId.toString(), msg);

		for (int i = 0; i < 40; i++) {
			if (this.sessionRepository.findByBookingId(bookingId).isPresent()) {
				return;
			}
			Thread.sleep(50);
		}

		assertThat(this.sessionRepository.findByBookingId(bookingId)).isPresent();
	}
}

