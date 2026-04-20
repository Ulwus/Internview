package io.internview.user_service.web.dto;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.Size;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@Builder
@RequiredArgsConstructor(onConstructor_ = @JsonCreator(mode = JsonCreator.Mode.PROPERTIES))
public class UpdateProfileRequest {

	@Size(min = 1, max = 100, message = "firstName 1-100 karakter olmalı")
	@JsonProperty("firstName")
	private final String firstName;

	@Size(min = 1, max = 100, message = "lastName 1-100 karakter olmalı")
	@JsonProperty("lastName")
	private final String lastName;

	@Size(max = 512, message = "avatarUrl en fazla 512 karakter olabilir")
	@JsonProperty("avatarUrl")
	private final String avatarUrl;
}
