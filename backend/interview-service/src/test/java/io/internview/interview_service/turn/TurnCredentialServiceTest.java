package io.internview.interview_service.turn;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class TurnCredentialServiceTest {

	private static final String TEST_SECRET = "test_hmac_secret";
	private static final long TEST_TTL = 86400;
	private static final List<String> TEST_URLS = List.of("stun:localhost:3478", "turn:localhost:3478");

	private TurnCredentialService turnCredentialService;

	@BeforeEach
	void setUp() {
		TurnConfig config = new TurnConfig();
		config.setSecret(TEST_SECRET);
		config.setTtlSeconds(TEST_TTL);
		config.setUrls(TEST_URLS);
		this.turnCredentialService = new TurnCredentialService(config);
	}

	@Test
	@DisplayName("Credential üretimi — username formatı 'expireTimestamp:userId' olmalı")
	void shouldGenerateUsernameWithTimestampAndUserId() {
		UUID userId = UUID.randomUUID();
		TurnCredentials credentials = this.turnCredentialService.generateCredentials(userId);

		assertThat(credentials.getUsername()).contains(":");
		String[] parts = credentials.getUsername().split(":");

		// İlk kısım timestamp, geri kalan userId
		long timestamp = Long.parseLong(parts[0]);
		assertThat(timestamp).isGreaterThan(System.currentTimeMillis() / 1000);

		String userIdPart = credentials.getUsername().substring(parts[0].length() + 1);
		assertThat(userIdPart).isEqualTo(userId.toString());
	}

	@Test
	@DisplayName("Credential üretimi — HMAC-SHA1 hesaplaması doğru olmalı")
	void shouldComputeValidHmacSha1Credential() throws Exception {
		UUID userId = UUID.randomUUID();
		TurnCredentials credentials = this.turnCredentialService.generateCredentials(userId);

		// Aynı HMAC'i bağımsız olarak hesapla ve karşılaştır
		Mac mac = Mac.getInstance("HmacSHA1");
		SecretKeySpec keySpec = new SecretKeySpec(
			TEST_SECRET.getBytes(StandardCharsets.UTF_8),
			"HmacSHA1"
		);
		mac.init(keySpec);
		byte[] expectedHmac = mac.doFinal(credentials.getUsername().getBytes(StandardCharsets.UTF_8));
		String expectedCredential = Base64.getEncoder().encodeToString(expectedHmac);

		assertThat(credentials.getCredential()).isEqualTo(expectedCredential);
	}

	@Test
	@DisplayName("TTL değeri yapılandırmadan gelmeli")
	void shouldReturnConfiguredTtl() {
		UUID userId = UUID.randomUUID();
		TurnCredentials credentials = this.turnCredentialService.generateCredentials(userId);

		assertThat(credentials.getTtl()).isEqualTo(TEST_TTL);
	}

	@Test
	@DisplayName("URL listesi yapılandırmadan gelmeli")
	void shouldReturnConfiguredUrls() {
		UUID userId = UUID.randomUUID();
		TurnCredentials credentials = this.turnCredentialService.generateCredentials(userId);

		assertThat(credentials.getUrls()).containsExactlyElementsOf(TEST_URLS);
	}

	@Test
	@DisplayName("Farklı userId'ler için farklı credential üretilmeli")
	void shouldGenerateUniqueCredentialsForDifferentUsers() {
		UUID userId1 = UUID.randomUUID();
		UUID userId2 = UUID.randomUUID();

		TurnCredentials creds1 = this.turnCredentialService.generateCredentials(userId1);
		TurnCredentials creds2 = this.turnCredentialService.generateCredentials(userId2);

		assertThat(creds1.getUsername()).isNotEqualTo(creds2.getUsername());
		assertThat(creds1.getCredential()).isNotEqualTo(creds2.getCredential());
	}

	@Test
	@DisplayName("Aynı userId ile üretilen credential, Base64 encoded olmalı")
	void shouldReturnBase64EncodedCredential() {
		UUID userId = UUID.randomUUID();
		TurnCredentials credentials = this.turnCredentialService.generateCredentials(userId);

		// Base64 decode hata vermemeli
		byte[] decoded = Base64.getDecoder().decode(credentials.getCredential());
		assertThat(decoded).isNotEmpty();
		// HMAC-SHA1 çıktısı her zaman 20 byte'tır
		assertThat(decoded).hasSize(20);
	}
}
