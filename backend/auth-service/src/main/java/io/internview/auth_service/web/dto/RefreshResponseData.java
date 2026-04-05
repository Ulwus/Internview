package io.internview.auth_service.web.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public record RefreshResponseData(@JsonProperty("access_token") String accessToken,
		@JsonProperty("expires_in") long expiresIn) {
}
