package io.internview.booking_service.web.dto;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@Builder
@RequiredArgsConstructor(onConstructor_ = @JsonCreator(mode = JsonCreator.Mode.PROPERTIES))
public class UpdateCandidateFeedbackRequest {

	@NotNull(message = "candidateRating zorunlu")
	@Min(value = 1, message = "candidateRating 1-10 arası olmalı")
	@Max(value = 10, message = "candidateRating 1-10 arası olmalı")
	@JsonProperty("candidateRating")
	private final Integer candidateRating;

	@NotBlank(message = "candidateComment zorunlu")
	@JsonProperty("candidateComment")
	private final String candidateComment;
}
