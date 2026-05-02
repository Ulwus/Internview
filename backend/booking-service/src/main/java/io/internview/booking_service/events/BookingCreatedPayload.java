package io.internview.booking_service.events;

import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class BookingCreatedPayload {

	@JsonProperty("booking_id")
	UUID bookingId;

	@JsonProperty("candidate_id")
	UUID candidateId;

	@JsonProperty("expert_id")
	UUID expertId;

	@JsonProperty("slot_id")
	UUID slotId;

	@JsonProperty("scheduled_time")
	Instant scheduledTime;

	@JsonProperty("status")
	String status;
}

