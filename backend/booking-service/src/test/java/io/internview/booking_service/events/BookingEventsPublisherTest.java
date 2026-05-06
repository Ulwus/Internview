package io.internview.booking_service.events;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;

import org.apache.kafka.clients.consumer.Consumer;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.test.EmbeddedKafkaBroker;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.kafka.test.utils.KafkaTestUtils;
import org.springframework.test.context.TestPropertySource;

@SpringBootTest
@EmbeddedKafka(partitions = 1, topics = { "booking-events" })
@TestPropertySource(properties = {
	"spring.kafka.bootstrap-servers=${spring.embedded.kafka.brokers}",
	"internview.kafka.topics.booking-events=booking-events"
})
class BookingEventsPublisherTest {

	@Autowired
	private EmbeddedKafkaBroker embeddedKafka;

	@Autowired
	private ApplicationEventPublisher eventPublisher;

	@Test
	void publishesBookingCreatedAfterCommit() {
		UUID bookingId = UUID.randomUUID();
		this.eventPublisher.publishEvent(new BookingCreatedDomainEvent(
			bookingId,
			UUID.randomUUID(),
			UUID.randomUUID(),
			UUID.randomUUID(),
			Instant.now(),
			"CONFIRMED"
		));

		Consumer<String, String> consumer = new DefaultKafkaConsumerFactory<String, String>(
			KafkaTestUtils.consumerProps(this.embeddedKafka, "booking-events-publisher-test", true),
			new StringDeserializer(),
			new StringDeserializer()
		).createConsumer();
		this.embeddedKafka.consumeFromAnEmbeddedTopic(consumer, "booking-events");

		ConsumerRecord<String, String> record = KafkaTestUtils.getSingleRecord(consumer, "booking-events");
		assertThat(record.value()).contains("\"event_type\":\"BOOKING_CREATED\"");
		assertThat(record.value()).contains(bookingId.toString());
	}
}

