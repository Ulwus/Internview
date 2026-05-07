package io.internview.booking_service.events;

import java.math.BigDecimal;
import java.util.UUID;

public record ExpertRatingUpdatedDomainEvent(
	UUID expertUserId,
	BigDecimal averageRating,
	long totalRated
) {
}

