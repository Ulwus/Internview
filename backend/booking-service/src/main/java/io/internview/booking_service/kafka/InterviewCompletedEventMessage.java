package io.internview.booking_service.kafka;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class InterviewCompletedEventMessage {

	@JsonProperty("event_type")
	private String eventType;

	@JsonProperty("event_id")
	private String eventId;

	@JsonProperty("timestamp")
	private String timestamp;

	@JsonProperty("payload")
	private InterviewCompletedPayload payload;
}

