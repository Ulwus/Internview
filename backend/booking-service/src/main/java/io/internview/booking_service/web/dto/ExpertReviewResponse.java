package io.internview.booking_service.web.dto;

import java.time.Instant;
import java.util.UUID;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class ExpertReviewResponse {
	UUID bookingId;
	Integer rating;
	String comment;
	Instant scheduledEnd;
}

