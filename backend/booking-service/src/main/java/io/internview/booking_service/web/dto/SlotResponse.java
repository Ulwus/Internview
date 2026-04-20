package io.internview.booking_service.web.dto;

import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

import io.internview.booking_service.domain.AvailabilitySlot;
import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class SlotResponse {

	@JsonProperty("id")
	UUID id;

	@JsonProperty("expertId")
	UUID expertId;

	@JsonProperty("startTime")
	Instant startTime;

	@JsonProperty("endTime")
	Instant endTime;

	@JsonProperty("booked")
	boolean booked;

	public static SlotResponse from(AvailabilitySlot slot) {
		return SlotResponse.builder()
			.id(slot.getId())
			.expertId(slot.getExpertId())
			.startTime(slot.getStartTime())
			.endTime(slot.getEndTime())
			.booked(slot.isBooked())
			.build();
	}
}
