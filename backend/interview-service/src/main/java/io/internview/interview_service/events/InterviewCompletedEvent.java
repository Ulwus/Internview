package io.internview.interview_service.events;

import java.time.Instant;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class InterviewCompletedEvent {

	@JsonProperty("event_type")
	String eventType;

	@JsonProperty("event_id")
	String eventId;

	@JsonProperty("timestamp")
	Instant timestamp;

	@JsonProperty("payload")
	InterviewCompletedPayload payload;
}

