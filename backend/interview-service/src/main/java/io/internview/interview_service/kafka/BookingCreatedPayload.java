package io.internview.interview_service.kafka;

import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Data;

@Data
public class BookingCreatedPayload {

	@JsonProperty("booking_id")
	private UUID bookingId;

	@JsonProperty("candidate_id")
	private UUID candidateId;

	@JsonProperty("expert_id")
	private UUID expertId;

	@JsonProperty("slot_id")
	private UUID slotId;

	@JsonProperty("scheduled_time")
	private Instant scheduledTime;

	@JsonProperty("status")
	private String status;
}

