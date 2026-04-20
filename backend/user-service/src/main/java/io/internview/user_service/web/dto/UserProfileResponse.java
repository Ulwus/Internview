package io.internview.user_service.web.dto;

import java.time.Instant;
import java.util.UUID;

import io.internview.user_service.domain.UserRole;
import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class UserProfileResponse {

	UUID id;
	String email;
	String firstName;
	String lastName;
	String avatarUrl;
	UserRole role;
	Instant createdAt;
	Instant updatedAt;
}
