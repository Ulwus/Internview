package io.internview.auth_service.web;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import io.internview.auth_service.service.AuthService;
import io.internview.auth_service.web.dto.LoginRequest;
import io.internview.auth_service.web.dto.LoginResponseData;
import io.internview.auth_service.web.dto.RefreshRequest;
import io.internview.auth_service.web.dto.RefreshResponseData;
import io.internview.auth_service.web.dto.RegisterRequest;
import io.internview.auth_service.web.dto.RegisterResponseData;
import jakarta.validation.Valid;

@RestController
public class AuthController {

	private final AuthService authService;

	public AuthController(AuthService authService) {
		this.authService = authService;
	}

	@PostMapping("/register")
	@ResponseStatus(HttpStatus.CREATED)
	public ApiResponse<RegisterResponseData> register(@Valid @RequestBody RegisterRequest request) {
		return ApiResponse.ok(this.authService.register(request));
	}

	@PostMapping("/login")
	public ApiResponse<LoginResponseData> login(@Valid @RequestBody LoginRequest request) {
		return ApiResponse.ok(this.authService.login(request));
	}

	@PostMapping("/refresh")
	public ApiResponse<RefreshResponseData> refresh(@Valid @RequestBody RefreshRequest request) {
		return ApiResponse.ok(this.authService.refresh(request));
	}
}
