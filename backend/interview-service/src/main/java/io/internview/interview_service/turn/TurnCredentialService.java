package io.internview.interview_service.turn;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.stereotype.Service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Coturn HMAC-based time-limited credential üretim servisi.
 * <p>
 * Coturn'ün "use-auth-secret" modu ile uyumludur.
 * <p>
 * Credential üretim algoritması:
 * <ol>
 *   <li>username = "expireTimestamp:userId"</li>
 *   <li>credential = Base64(HMAC-SHA1(secret, username))</li>
 * </ol>
 *
 * @see <a href="https://github.com/coturn/coturn/wiki/turnserver#turn-rest-api">Coturn REST API</a>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TurnCredentialService {

	private static final String HMAC_ALGORITHM = "HmacSHA1";

	private final TurnConfig turnConfig;

	/**
	 * Belirtilen kullanıcı için HMAC-based geçici TURN credential üretir.
	 *
	 * @param userId credential üretilecek kullanıcının ID'si
	 * @return STUN/TURN URL listesi ve geçici credential bilgisi
	 */
	public TurnCredentials generateCredentials(UUID userId) {
		long expireTimestamp = Instant.now().getEpochSecond() + this.turnConfig.getTtlSeconds();
		String username = expireTimestamp + ":" + userId.toString();

		String credential = this.computeHmac(username);

		log.debug("TURN credential üretildi: userId={}, ttl={}s", userId, this.turnConfig.getTtlSeconds());

		return TurnCredentials.builder()
			.username(username)
			.credential(credential)
			.ttl(this.turnConfig.getTtlSeconds())
			.urls(this.turnConfig.getUrls())
			.build();
	}

	/**
	 * Verilen username için HMAC-SHA1 hesaplar ve Base64 encode eder.
	 */
	private String computeHmac(String username) {
		try {
			Mac mac = Mac.getInstance(HMAC_ALGORITHM);
			SecretKeySpec keySpec = new SecretKeySpec(
				this.turnConfig.getSecret().getBytes(StandardCharsets.UTF_8),
				HMAC_ALGORITHM
			);
			mac.init(keySpec);
			byte[] hmacBytes = mac.doFinal(username.getBytes(StandardCharsets.UTF_8));
			return Base64.getEncoder().encodeToString(hmacBytes);
		}
		catch (Exception ex) {
			throw new IllegalStateException("HMAC-SHA1 hesaplaması başarısız: " + ex.getMessage(), ex);
		}
	}
}
