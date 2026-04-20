package io.internview.auth_service.web.dto;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@Builder
@RequiredArgsConstructor(onConstructor_ = @JsonCreator(mode = JsonCreator.Mode.PROPERTIES))
public class LoginRequest {

	@NotBlank(message = "email zorunlu")
	@Email(message = "geçerli bir email adresi giriniz")
	@JsonProperty("email")
	private final String email;

	@NotBlank(message = "password zorunlu")
	@JsonProperty("password")
	private final String password;
}
