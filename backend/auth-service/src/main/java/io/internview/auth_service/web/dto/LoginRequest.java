package io.internview.auth_service.web.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record LoginRequest(@NotBlank @Email @JsonProperty("email") String email,
		@NotBlank @JsonProperty("password") String password) {
}
