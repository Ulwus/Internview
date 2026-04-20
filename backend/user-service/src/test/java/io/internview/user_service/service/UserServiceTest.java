package io.internview.user_service.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import io.internview.user_service.domain.User;
import io.internview.user_service.domain.UserRole;
import io.internview.user_service.error.UserNotFoundException;
import io.internview.user_service.repository.UserRepository;
import io.internview.user_service.web.dto.UpdateProfileRequest;
import io.internview.user_service.web.dto.UserProfileResponse;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

	@Mock
	private UserRepository userRepository;

	@InjectMocks
	private UserService userService;

	private User user;
	private UUID userId;

	@BeforeEach
	void setUp() {
		userId = UUID.randomUUID();
		user = User.builder()
			.id(userId)
			.email("ali@example.com")
			.passwordHash("hash")
			.firstName("Ali")
			.lastName("Yılmaz")
			.role(UserRole.CANDIDATE)
			.build();
	}

	@Test
	void getById_returnsProfile() {
		when(userRepository.findById(userId)).thenReturn(Optional.of(user));

		UserProfileResponse response = userService.getById(userId);

		assertThat(response.getId()).isEqualTo(userId);
		assertThat(response.getEmail()).isEqualTo("ali@example.com");
		assertThat(response.getFirstName()).isEqualTo("Ali");
	}

	@Test
	void getById_whenUserMissing_throws() {
		when(userRepository.findById(any())).thenReturn(Optional.empty());

		assertThatThrownBy(() -> userService.getById(UUID.randomUUID()))
			.isInstanceOf(UserNotFoundException.class);
	}

	@Test
	void updateProfile_mergesProvidedFieldsOnly() {
		when(userRepository.findById(userId)).thenReturn(Optional.of(user));

		UpdateProfileRequest request = UpdateProfileRequest.builder()
			.firstName("Ahmet")
			.avatarUrl("https://cdn.example.com/a.png")
			.build();

		UserProfileResponse response = userService.updateProfile(userId, request);

		assertThat(response.getFirstName()).isEqualTo("Ahmet");
		assertThat(response.getLastName()).isEqualTo("Yılmaz");
		assertThat(response.getAvatarUrl()).isEqualTo("https://cdn.example.com/a.png");
	}

	@Test
	void updateProfile_whenAvatarBlank_clearsAvatar() {
		user.setAvatarUrl("https://old.example.com/a.png");
		when(userRepository.findById(userId)).thenReturn(Optional.of(user));

		UpdateProfileRequest request = UpdateProfileRequest.builder().avatarUrl("  ").build();

		UserProfileResponse response = userService.updateProfile(userId, request);

		assertThat(response.getAvatarUrl()).isNull();
	}
}
