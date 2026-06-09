package io.internview.booking_service.kafka;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class InterviewCompletedPayload {

	@JsonProperty("booking_id")
	private UUID bookingId;
}

