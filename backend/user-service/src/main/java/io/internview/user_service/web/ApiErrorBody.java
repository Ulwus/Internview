package io.internview.user_service.web;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class ApiErrorBody {

	@JsonProperty("code")
	String code;

	@JsonProperty("message")
	String message;
}
