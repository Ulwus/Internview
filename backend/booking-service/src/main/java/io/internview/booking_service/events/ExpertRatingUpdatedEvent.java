package io.internview.booking_service.events;

import java.time.Instant;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExpertRatingUpdatedEvent {
	private String eventType;
	private String eventId;
	private Instant timestamp;
	private ExpertRatingUpdatedPayload payload;
}

