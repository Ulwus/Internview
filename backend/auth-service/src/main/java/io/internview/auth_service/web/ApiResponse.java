package io.internview.auth_service.web;

import java.time.Instant;

import com.fasterxml.jackson.annotation.JsonProperty;

public record ApiResponse<T>(boolean success, T data, @JsonProperty("timestamp") Instant timestamp) {

	public static <T> ApiResponse<T> ok(T data) {
		return new ApiResponse<>(true, data, Instant.now());
	}
}
