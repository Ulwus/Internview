package io.internview.auth_service.web;

import java.time.Instant;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class ApiErrorResponse {

	boolean success;

	@JsonProperty("error")
	ApiErrorBody error;

	@JsonProperty("timestamp")
	Instant timestamp;

	public static ApiErrorResponse of(String code, String message) {
		return ApiErrorResponse.builder()
			.success(false)
			.error(ApiErrorBody.builder().code(code).message(message).build())
			.timestamp(Instant.now())
			.build();
	}
}
