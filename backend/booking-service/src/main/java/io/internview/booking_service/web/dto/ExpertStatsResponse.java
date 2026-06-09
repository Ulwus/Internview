package io.internview.booking_service.web.dto;

import java.math.BigDecimal;
import java.util.UUID;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class ExpertStatsResponse {
	UUID expertUserId;
	BigDecimal averageRating;
	long totalRated;
	long completedCount;
	long cancelledCount;
}

