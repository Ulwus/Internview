package io.internview.user_service.web.dto;

import java.math.BigDecimal;
import java.util.Set;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@Builder
@RequiredArgsConstructor(onConstructor_ = @JsonCreator(mode = JsonCreator.Mode.PROPERTIES))
public class UpdateExpertProfileRequest {

	@Size(max = 160)
	@JsonProperty("headline")
	private final String headline;

	@Size(max = 10_000)
	@JsonProperty("bio")
	private final String bio;

	@Size(max = 160)
	@JsonProperty("company")
	private final String company;

	@Size(max = 120)
	@JsonProperty("industrySlug")
	private final String industrySlug;

	@JsonProperty("skillSlugs")
	private final Set<@Size(max = 120) String> skillSlugs;

	@Min(0)
	@JsonProperty("yearsOfExperience")
	private final Integer yearsOfExperience;

	@DecimalMin(value = "0.0", inclusive = true)
	@JsonProperty("hourlyRate")
	private final BigDecimal hourlyRate;

	@Pattern(regexp = "^[A-Z]{3}$", message = "currency 3 karakterli ISO kodu olmalı")
	@JsonProperty("currency")
	private final String currency;

	@JsonProperty("isAvailable")
	private final Boolean isAvailable;
}
