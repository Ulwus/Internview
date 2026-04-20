package io.internview.booking_service.web.dto;

import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

import io.internview.booking_service.domain.Booking;
import io.internview.booking_service.domain.BookingStatus;
import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class BookingResponse {

	@JsonProperty("id")
	UUID id;

	@JsonProperty("candidateId")
	UUID candidateId;

	@JsonProperty("expertId")
	UUID expertId;

	@JsonProperty("slotId")
	UUID slotId;

	@JsonProperty("status")
	BookingStatus status;

	@JsonProperty("scheduledStart")
	Instant scheduledStart;

	@JsonProperty("scheduledEnd")
	Instant scheduledEnd;

	public static BookingResponse from(Booking booking) {
		return BookingResponse.builder()
			.id(booking.getId())
			.candidateId(booking.getCandidateId())
			.expertId(booking.getExpertId())
			.slotId(booking.getSlotId())
			.status(booking.getStatus())
			.scheduledStart(booking.getScheduledStart())
			.scheduledEnd(booking.getScheduledEnd())
			.build();
	}
}
