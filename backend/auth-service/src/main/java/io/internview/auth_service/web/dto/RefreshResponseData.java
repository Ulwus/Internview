package io.internview.auth_service.web.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class RefreshResponseData {

	@JsonProperty("access_token")
	String accessToken;

	@JsonProperty("expires_in")
	long expiresIn;
}
