package io.internview.auth_service.web.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import io.internview.auth_service.domain.UserRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record RegisterRequest(@NotBlank @Email @JsonProperty("email") String email,
		@NotBlank @Size(min = 8, max = 128) @JsonProperty("password") String password,
		@NotBlank @Size(max = 100) @JsonProperty("first_name") String firstName,
		@NotBlank @Size(max = 100) @JsonProperty("last_name") String lastName,
		@NotNull @JsonProperty("role") UserRole role) {
}
