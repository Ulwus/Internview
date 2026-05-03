package io.internview.interview_service.support;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;

public final class JwtTestTokens {

	private JwtTestTokens() {
	}

	public static String hs256Token(String rawSecret, UUID userId, String role) {
		try {
			byte[] keyBytes = rawSecret.getBytes(StandardCharsets.UTF_8);
			Instant now = Instant.now();
			JWTClaimsSet claims = new JWTClaimsSet.Builder()
				.subject(userId.toString())
				.issueTime(Date.from(now))
				.expirationTime(Date.from(now.plusSeconds(3600)))
				.claim("role", role)
				.build();
			SignedJWT jwt = new SignedJWT(new JWSHeader(JWSAlgorithm.HS256), claims);
			jwt.sign(new MACSigner(keyBytes));
			return jwt.serialize();
		}
		catch (JOSEException e) {
			throw new IllegalStateException("JWT test token üretilemedi", e);
		}
	}
}
