package io.internview.interview_service.kafka;

import java.time.Instant;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Data;

@Data
public class BookingCreatedEventMessage {

	@JsonProperty("event_type")
	private String eventType;

	@JsonProperty("event_id")
	private String eventId;

	@JsonProperty("timestamp")
	private Instant timestamp;

	@JsonProperty("payload")
	private BookingCreatedPayload payload;
}

