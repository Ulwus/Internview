package io.internview.auth_service.web.dto;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class LoginResponseData {

	@JsonProperty("user_id")
	UUID userId;

	@JsonProperty("access_token")
	String accessToken;

	@JsonProperty("refresh_token")
	String refreshToken;

	@JsonProperty("expires_in")
	long expiresIn;
}
