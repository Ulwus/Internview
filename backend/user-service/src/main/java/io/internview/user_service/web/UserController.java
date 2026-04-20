package io.internview.user_service.web;

import java.util.UUID;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.internview.user_service.service.UserService;
import io.internview.user_service.web.dto.UpdateProfileRequest;
import io.internview.user_service.web.dto.UserProfileResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

	private final UserService userService;

	@GetMapping("/profile")
	@PreAuthorize("isAuthenticated()")
	public ApiResponse<UserProfileResponse> getProfile(@AuthenticationPrincipal Jwt jwt) {
		UUID userId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.userService.getById(userId));
	}

	@PutMapping("/profile")
	@PreAuthorize("isAuthenticated()")
	public ApiResponse<UserProfileResponse> updateProfile(
		@AuthenticationPrincipal Jwt jwt,
		@Valid @RequestBody UpdateProfileRequest request) {
		UUID userId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.userService.updateProfile(userId, request));
	}
}
