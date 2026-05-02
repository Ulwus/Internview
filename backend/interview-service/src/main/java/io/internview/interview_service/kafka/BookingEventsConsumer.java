package io.internview.interview_service.kafka;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import io.internview.interview_service.service.InterviewSessionService;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class BookingEventsConsumer {

	private final InterviewSessionService interviewSessionService;

	private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper().registerModule(new JavaTimeModule());

	@KafkaListener(topics = "${internview.kafka.topics.booking-events}", groupId = "${spring.kafka.consumer.group-id}")
	public void onMessage(String rawJson) throws Exception {
		BookingCreatedEventMessage message = OBJECT_MAPPER.readValue(rawJson, BookingCreatedEventMessage.class);
		if (message == null || !"BOOKING_CREATED".equalsIgnoreCase(message.getEventType())) {
			return;
		}
		this.interviewSessionService.ensureSessionForBookingCreated(message.getPayload());
	}
}

