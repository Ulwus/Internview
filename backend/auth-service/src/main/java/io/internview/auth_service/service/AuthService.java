package io.internview.auth_service.service;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.auth_service.domain.RefreshToken;
import io.internview.auth_service.domain.User;
import io.internview.auth_service.domain.UserRole;
import io.internview.auth_service.error.EmailAlreadyRegisteredException;
import io.internview.auth_service.error.InvalidCredentialsException;
import io.internview.auth_service.error.InvalidRefreshTokenException;
import io.internview.auth_service.error.UserNotFoundException;
import io.internview.auth_service.repository.RefreshTokenRepository;
import io.internview.auth_service.repository.UserRepository;
import io.internview.auth_service.security.JwtService;
import io.internview.auth_service.security.TokenHasher;
import io.internview.auth_service.web.dto.LoginRequest;
import io.internview.auth_service.web.dto.LoginResponseData;
import io.internview.auth_service.web.dto.MeResponseData;
import io.internview.auth_service.web.dto.RefreshRequest;
import io.internview.auth_service.web.dto.RefreshResponseData;
import io.internview.auth_service.web.dto.RegisterRequest;
import io.internview.auth_service.web.dto.RegisterResponseData;

@Service
public class AuthService {

	private static final SecureRandom RANDOM = new SecureRandom();

	private final UserRepository userRepository;
	private final RefreshTokenRepository refreshTokenRepository;
	private final PasswordEncoder passwordEncoder;
	private final JwtService jwtService;
	private final long refreshTokenTtlSeconds;

	public AuthService(UserRepository userRepository, RefreshTokenRepository refreshTokenRepository,
			PasswordEncoder passwordEncoder, JwtService jwtService,
			@Value("${auth.jwt.refresh-token-ttl-seconds}") long refreshTokenTtlSeconds) {
		this.userRepository = userRepository;
		this.refreshTokenRepository = refreshTokenRepository;
		this.passwordEncoder = passwordEncoder;
		this.jwtService = jwtService;
		this.refreshTokenTtlSeconds = refreshTokenTtlSeconds;
	}

	@Transactional
	public RegisterResponseData register(RegisterRequest request) {
		if (this.userRepository.existsByEmailIgnoreCase(request.email())) {
			throw new EmailAlreadyRegisteredException("Email is already registered.");
		}
		User user = User.builder()
			.id(UUID.randomUUID())
			.email(request.email().trim().toLowerCase())
			.passwordHash(this.passwordEncoder.encode(request.password()))
			.firstName(request.firstName().trim())
			.lastName(request.lastName().trim())
			.role(request.role())
			.build();
		this.userRepository.save(user);
		String access = this.jwtService.createAccessToken(user);
		String rawRefresh = newRefreshTokenValue();
		persistRefreshToken(user, rawRefresh);
		return new RegisterResponseData(user.getId(), user.getEmail(), access, rawRefresh,
				this.jwtService.getAccessTokenTtlSeconds());
	}

	@Transactional
	public LoginResponseData login(LoginRequest request) {
		User user = this.userRepository.findByEmailIgnoreCase(request.email().trim().toLowerCase())
			.orElseThrow(() -> new InvalidCredentialsException("Invalid email or password."));
		if (!this.passwordEncoder.matches(request.password(), user.getPasswordHash())) {
			throw new InvalidCredentialsException("Invalid email or password.");
		}
		String access = this.jwtService.createAccessToken(user);
		String rawRefresh = newRefreshTokenValue();
		persistRefreshToken(user, rawRefresh);
		return new LoginResponseData(user.getId(), access, rawRefresh, this.jwtService.getAccessTokenTtlSeconds());
	}

	@Transactional
	public RefreshResponseData refresh(RefreshRequest request) {
		String hash = TokenHasher.sha256Hex(request.refreshToken());
		RefreshToken stored = this.refreshTokenRepository.findByTokenHash(hash)
			.orElseThrow(() -> new InvalidRefreshTokenException("Invalid or expired refresh token."));
		if (stored.getRevokedAt() != null) {
			throw new InvalidRefreshTokenException("Invalid or expired refresh token.");
		}
		if (stored.getExpiresAt().isBefore(Instant.now())) {
			throw new InvalidRefreshTokenException("Invalid or expired refresh token.");
		}
		User user = stored.getUser();
		String access = this.jwtService.createAccessToken(user);
		return new RefreshResponseData(access, this.jwtService.getAccessTokenTtlSeconds());
	}

	@Transactional(readOnly = true)
	public MeResponseData me(UUID userId) {
		User user = this.userRepository.findById(userId)
			.orElseThrow(() -> new UserNotFoundException("User not found."));
		return new MeResponseData(user.getId(), user.getEmail(), user.getFirstName(), user.getLastName(),
				List.of(user.getRole().name()));
	}

	private void persistRefreshToken(User user, String rawRefresh) {
		String hash = TokenHasher.sha256Hex(rawRefresh);
		RefreshToken entity = RefreshToken.builder()
			.id(UUID.randomUUID())
			.user(user)
			.tokenHash(hash)
			.expiresAt(Instant.now().plusSeconds(this.refreshTokenTtlSeconds))
			.build();
		this.refreshTokenRepository.save(entity);
	}

	private static String newRefreshTokenValue() {
		byte[] buf = new byte[48];
		RANDOM.nextBytes(buf);
		return Base64.getUrlEncoder().withoutPadding().encodeToString(buf);
	}
}
