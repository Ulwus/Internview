package io.internview.user_service.web.dto;

import java.math.BigDecimal;
import java.util.Set;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class UpsertShopRequest {
	String description;
	Integer yearsOfExperience;
	BigDecimal hourlyRate;
	String currency;
	String industrySlug;
	Set<String> skillSlugs;
	@NotNull
	Boolean isPublished;
}

