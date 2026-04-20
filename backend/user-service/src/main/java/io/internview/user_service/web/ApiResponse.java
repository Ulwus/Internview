package io.internview.user_service.web;

import java.time.Instant;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class ApiResponse<T> {

	boolean success;

	T data;

	@JsonProperty("timestamp")
	Instant timestamp;

	public static <T> ApiResponse<T> ok(T data) {
		return ApiResponse.<T>builder().success(true).data(data).timestamp(Instant.now()).build();
	}
}
