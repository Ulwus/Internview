package io.internview.auth_service.web;

import java.time.Instant;

import com.fasterxml.jackson.annotation.JsonProperty;

public record ApiErrorResponse(boolean success, @JsonProperty("error") ApiErrorBody error,
		@JsonProperty("timestamp") Instant timestamp) {

	public static ApiErrorResponse of(String code, String message) {
		return new ApiErrorResponse(false, new ApiErrorBody(code, message), Instant.now());
	}
}
