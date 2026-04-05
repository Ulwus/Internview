package io.internview.auth_service.web.dto;

import java.util.List;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class MeResponseData {

	@JsonProperty("user_id")
	UUID userId;

	@JsonProperty("email")
	String email;

	@JsonProperty("first_name")
	String firstName;

	@JsonProperty("last_name")
	String lastName;

	@JsonProperty("roles")
	List<String> roles;
}
