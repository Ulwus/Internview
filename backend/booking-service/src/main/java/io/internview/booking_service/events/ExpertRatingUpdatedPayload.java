package io.internview.booking_service.events;

import java.math.BigDecimal;
import java.util.UUID;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExpertRatingUpdatedPayload {
	private UUID expertUserId;
	private BigDecimal averageRating;
	private Long totalRated;
}

