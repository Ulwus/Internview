package io.internview.interview_service.web.dto;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.Min;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@Builder
@RequiredArgsConstructor(onConstructor_ = @JsonCreator(mode = JsonCreator.Mode.PROPERTIES))
public class CompleteSessionRequest {

	@Min(value = 0, message = "durationSeconds 0'dan küçük olamaz")
	@JsonProperty("durationSeconds")
	private final long durationSeconds;

	@JsonProperty("recordedVideoUrl")
	private final String recordedVideoUrl;
}

