package io.internview.user_service.web.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class ShopSummaryResponse {
	UUID id;
	UUID expertUserId;
	String expertFirstName;
	String expertLastName;
	String expertAvatarUrl;

	IndustryResponse industry;
	Set<SkillResponse> skills;

	String description;
	Integer yearsOfExperience;
	BigDecimal hourlyRate;
	String currency;
	Boolean isPublished;

	// From ExpertProfile join
	BigDecimal averageRating;
	Boolean isAvailable;

	Instant createdAt;
	Instant updatedAt;
}

