package io.internview.auth_service.web.dto;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import io.internview.auth_service.domain.UserRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@Builder
@RequiredArgsConstructor(onConstructor_ = @JsonCreator(mode = JsonCreator.Mode.PROPERTIES))
public class RegisterRequest {

	@NotBlank
	@Email
	@JsonProperty("email")
	private final String email;

	@NotBlank
	@Size(min = 8, max = 128)
	@JsonProperty("password")
	private final String password;

	@NotBlank
	@Size(max = 100)
	@JsonProperty("first_name")
	private final String firstName;

	@NotBlank
	@Size(max = 100)
	@JsonProperty("last_name")
	private final String lastName;

	@NotNull
	@JsonProperty("role")
	private final UserRole role;
}
