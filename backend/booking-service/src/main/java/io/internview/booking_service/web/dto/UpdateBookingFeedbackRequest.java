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
public class UpdateBookingFeedbackRequest {

	@NotNull(message = "expertRating zorunlu")
	@Min(value = 1, message = "expertRating 1-10 arası olmalı")
	@Max(value = 10, message = "expertRating 1-10 arası olmalı")
	@JsonProperty("expertRating")
	private final Integer expertRating;

	@NotBlank(message = "expertComment zorunlu")
	@JsonProperty("expertComment")
	private final String expertComment;
}
