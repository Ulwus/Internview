package io.internview.auth_service.security;

import java.time.Instant;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

import io.internview.auth_service.domain.User;
import io.internview.auth_service.domain.UserRole;

@Service
public class JwtService {

	private final JwtEncoder jwtEncoder;
	private final long accessTokenTtlSeconds;

	public JwtService(JwtEncoder jwtEncoder,
			@Value("${auth.jwt.access-token-ttl-seconds}") long accessTokenTtlSeconds) {
		this.jwtEncoder = jwtEncoder;
		this.accessTokenTtlSeconds = accessTokenTtlSeconds;
	}

	public String createAccessToken(User user) {
		Instant now = Instant.now();
		JwsHeader jws = JwsHeader.with(MacAlgorithm.HS256).build();
		JwtClaimsSet claims = JwtClaimsSet.builder()
			.subject(user.getId().toString())
			.issuedAt(now)
			.expiresAt(now.plusSeconds(accessTokenTtlSeconds))
			.claim("email", user.getEmail())
			.claim("role", user.getRole().name())
			.build();
		return this.jwtEncoder.encode(JwtEncoderParameters.from(jws, claims)).getTokenValue();
	}

	public long getAccessTokenTtlSeconds() {
		return this.accessTokenTtlSeconds;
	}

	public String createAccessToken(UUID userId, String email, UserRole role) {
		Instant now = Instant.now();
		JwsHeader jws = JwsHeader.with(MacAlgorithm.HS256).build();
		JwtClaimsSet claims = JwtClaimsSet.builder()
			.subject(userId.toString())
			.issuedAt(now)
			.expiresAt(now.plusSeconds(accessTokenTtlSeconds))
			.claim("email", email)
			.claim("role", role.name())
			.build();
		return this.jwtEncoder.encode(JwtEncoderParameters.from(jws, claims)).getTokenValue();
	}
}
