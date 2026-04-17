package io.internview.user_service.service;

import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.user_service.domain.User;
import io.internview.user_service.error.UserNotFoundException;
import io.internview.user_service.repository.UserRepository;
import io.internview.user_service.web.dto.UpdateProfileRequest;
import io.internview.user_service.web.dto.UserProfileResponse;
import io.internview.user_service.web.mapper.UserMapper;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class UserService {

	private final UserRepository userRepository;

	@Transactional(readOnly = true)
	public UserProfileResponse getById(UUID userId) {
		User user = userRepository.findById(userId)
			.orElseThrow(() -> new UserNotFoundException("Kullanıcı bulunamadı: " + userId));
		return UserMapper.toProfileResponse(user);
	}

	@Transactional
	public UserProfileResponse updateProfile(UUID userId, UpdateProfileRequest request) {
		User user = userRepository.findById(userId)
			.orElseThrow(() -> new UserNotFoundException("Kullanıcı bulunamadı: " + userId));

		if (request.getFirstName() != null) {
			user.setFirstName(request.getFirstName());
		}
		if (request.getLastName() != null) {
			user.setLastName(request.getLastName());
		}
		if (request.getAvatarUrl() != null) {
			user.setAvatarUrl(request.getAvatarUrl().isBlank() ? null : request.getAvatarUrl());
		}

		return UserMapper.toProfileResponse(user);
	}
}
