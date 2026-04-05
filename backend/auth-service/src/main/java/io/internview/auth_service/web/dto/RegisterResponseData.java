package io.internview.auth_service.web.dto;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

public record RegisterResponseData(@JsonProperty("user_id") UUID userId, @JsonProperty("email") String email,
		@JsonProperty("access_token") String accessToken, @JsonProperty("refresh_token") String refreshToken,
		@JsonProperty("expires_in") long expiresIn) {
}
