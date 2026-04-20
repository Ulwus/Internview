package io.internview.user_service.web.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class ExpertDetailResponse {

	UUID id;
	UUID userId;
	String email;
	String firstName;
	String lastName;
	String avatarUrl;
	String headline;
	String bio;
	String company;
	IndustryResponse industry;
	List<SkillResponse> skills;
	Integer yearsOfExperience;
	BigDecimal hourlyRate;
	String currency;
	BigDecimal averageRating;
	Integer totalSessions;
	Boolean isVerified;
	Boolean isAvailable;
	Instant createdAt;
	Instant updatedAt;
}
