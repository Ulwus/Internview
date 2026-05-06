package io.internview.booking_service.web.dto;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@Builder
@RequiredArgsConstructor(onConstructor_ = @JsonCreator(mode = JsonCreator.Mode.PROPERTIES))
public class UpdateBookingFeedbackRequest {

	@Min(value = 1, message = "expertRating 1-5 arası olmalı")
	@Max(value = 5, message = "expertRating 1-5 arası olmalı")
	@JsonProperty("expertRating")
	private final Integer expertRating;

	@JsonProperty("expertComment")
	private final String expertComment;
}

