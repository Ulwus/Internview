package io.internview.interview_service.web;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.jwt.Jwt;

import io.internview.interview_service.turn.TurnCredentialService;
import io.internview.interview_service.turn.TurnCredentials;

/**
 * TurnController birim testi.
 * Spring context yüklemeden mock nesneler ile doğrulama yapar.
 */
class TurnControllerTest {

	private TurnCredentialService turnCredentialService;
	private TurnController turnController;

	@BeforeEach
	void setUp() {
		this.turnCredentialService = Mockito.mock(TurnCredentialService.class);
		this.turnController = new TurnController(this.turnCredentialService);
	}

	@Test
	@DisplayName("getCredentials — Authenticated kullanıcıya credential dönmeli")
	void shouldReturnCredentialsForAuthenticatedUser() {
		UUID userId = UUID.randomUUID();
		TurnCredentials expectedCreds = TurnCredentials.builder()
			.username("1700000000:" + userId)
			.credential("abc123==")
			.ttl(86400)
			.urls(List.of("stun:localhost:3478", "turn:localhost:3478"))
			.build();

		Mockito.when(this.turnCredentialService.generateCredentials(userId)).thenReturn(expectedCreds);

		Jwt jwt = Jwt.withTokenValue("test-token")
			.header("alg", "HS256")
			.subject(userId.toString())
			.claim("role", "CANDIDATE")
			.build();

		ResponseEntity<TurnCredentials> response = this.turnController.getCredentials(jwt);

		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(response.getBody()).isNotNull();
		assertThat(response.getBody().getUsername()).isEqualTo(expectedCreds.getUsername());
		assertThat(response.getBody().getCredential()).isEqualTo(expectedCreds.getCredential());
		assertThat(response.getBody().getTtl()).isEqualTo(86400);
		assertThat(response.getBody().getUrls()).containsExactly("stun:localhost:3478", "turn:localhost:3478");
	}

	@Test
	@DisplayName("getCredentials — Farklı userId'ler için service doğru çağrılmalı")
	void shouldCallServiceWithCorrectUserId() {
		UUID userId = UUID.randomUUID();
		TurnCredentials creds = TurnCredentials.builder()
			.username("1700000000:" + userId)
			.credential("xyz789==")
			.ttl(3600)
			.urls(List.of("turn:example.com:3478"))
			.build();

		Mockito.when(this.turnCredentialService.generateCredentials(userId)).thenReturn(creds);

		Jwt jwt = Jwt.withTokenValue("token")
			.header("alg", "HS256")
			.subject(userId.toString())
			.build();

		this.turnController.getCredentials(jwt);

		Mockito.verify(this.turnCredentialService).generateCredentials(userId);
	}

	@Test
	@DisplayName("getCredentials — Response 200 OK olmalı")
	void shouldReturn200Ok() {
		UUID userId = UUID.randomUUID();
		TurnCredentials creds = TurnCredentials.builder()
			.username("ts:" + userId)
			.credential("cred")
			.ttl(100)
			.urls(List.of("stun:host:3478"))
			.build();

		Mockito.when(this.turnCredentialService.generateCredentials(userId)).thenReturn(creds);

		Jwt jwt = Jwt.withTokenValue("t")
			.header("alg", "HS256")
			.subject(userId.toString())
			.build();

		ResponseEntity<TurnCredentials> response = this.turnController.getCredentials(jwt);

		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
	}
}
