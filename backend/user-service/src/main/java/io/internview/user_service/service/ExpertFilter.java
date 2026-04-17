package io.internview.user_service.service;

import java.math.BigDecimal;
import java.util.Set;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class ExpertFilter {

	String industrySlug;
	Set<String> skillSlugs;
	BigDecimal minRating;
	BigDecimal maxHourlyRate;
	Boolean isAvailable;
	String search;
}
