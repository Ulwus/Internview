package io.internview.booking_service.kafka;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class InterviewCompletedEventMessage {

	@JsonProperty("event_type")
	private String eventType;

	@JsonProperty("payload")
	private InterviewCompletedPayload payload;
}

