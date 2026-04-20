package io.internview.user_service.web.mapper;

import io.internview.user_service.domain.User;
import io.internview.user_service.web.dto.UserProfileResponse;

public final class UserMapper {

	private UserMapper() {
	}

	public static UserProfileResponse toProfileResponse(User user) {
		return UserProfileResponse.builder()
			.id(user.getId())
			.email(user.getEmail())
			.firstName(user.getFirstName())
			.lastName(user.getLastName())
			.avatarUrl(user.getAvatarUrl())
			.role(user.getRole())
			.createdAt(user.getCreatedAt())
			.updatedAt(user.getUpdatedAt())
			.build();
	}
}
