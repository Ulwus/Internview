package io.internview.auth_service.web;

import java.util.UUID;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import io.internview.auth_service.service.AuthService;
import io.internview.auth_service.web.dto.MeResponseData;

@RestController
public class MeController {

	private final AuthService authService;

	public MeController(AuthService authService) {
		this.authService = authService;
	}

	@GetMapping("/me")
	@PreAuthorize("isAuthenticated()")
	public ApiResponse<MeResponseData> me(@AuthenticationPrincipal Jwt jwt) {
		UUID userId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.authService.me(userId));
	}
}
