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

	@NotBlank(message = "email zorunlu")
	@Email(message = "geçerli bir email adresi giriniz")
	@JsonProperty("email")
	private final String email;

	@NotBlank(message = "password zorunlu")
	@Size(min = 8, max = 128, message = "password 8 ile 128 karakter arasında olmalı")
	@JsonProperty("password")
	private final String password;

	@NotBlank(message = "first_name zorunlu")
	@Size(max = 100, message = "first_name en fazla 100 karakter olabilir")
	@JsonProperty("first_name")
	private final String firstName;

	@NotBlank(message = "last_name zorunlu")
	@Size(max = 100, message = "last_name en fazla 100 karakter olabilir")
	@JsonProperty("last_name")
	private final String lastName;

	@NotNull(message = "role zorunlu")
	@JsonProperty("role")
	private final UserRole role;
}
