package io.internview.booking_service.kafka;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import io.internview.booking_service.service.BookingCompletionService;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class InterviewEventsConsumer {

	private final BookingCompletionService bookingCompletionService;

	private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper().registerModule(new JavaTimeModule());

	@KafkaListener(topics = "${internview.kafka.topics.interview-events}", groupId = "${spring.kafka.consumer.group-id:booking-service}")
	public void onMessage(String rawJson) throws Exception {
		InterviewCompletedEventMessage message = OBJECT_MAPPER.readValue(rawJson, InterviewCompletedEventMessage.class);
		if (message == null || !"INTERVIEW_COMPLETED".equalsIgnoreCase(message.getEventType())) {
			return;
		}
		if (message.getPayload() == null || message.getPayload().getBookingId() == null) {
			return;
		}
		this.bookingCompletionService.markCompletedFromInterview(message.getPayload().getBookingId());
	}
}

