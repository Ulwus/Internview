package io.internview.auth_service;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.web.client.DefaultResponseErrorHandler;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class AuthFlowIntegrationTest {

	@LocalServerPort
	private int port;

	private RestTemplate restTemplate;

	private final ObjectMapper objectMapper = new ObjectMapper();

	@BeforeEach
	void setUp() {
		this.restTemplate = new RestTemplate();
		this.restTemplate.setErrorHandler(new DefaultResponseErrorHandler() {
			@Override
			public boolean hasError(ClientHttpResponse response) throws IOException {
				return false;
			}
		});
	}

	private String url(String path) {
		return "http://127.0.0.1:" + this.port + path;
	}

	@Test
	void registerLoginRefreshAndMe() throws Exception {
		String regBody = """
				{"email":"flow@example.com","password":"SecurePass123!","first_name":"A","last_name":"B","role":"CANDIDATE"}
				""";
		ResponseEntity<String> reg = this.restTemplate.postForEntity(url("/register"), jsonEntity(regBody), String.class);
		assertThat(reg.getStatusCode()).isEqualTo(HttpStatus.CREATED);
		JsonNode regJson = this.objectMapper.readTree(reg.getBody());
		assertThat(regJson.path("success").asBoolean()).isTrue();
		assertThat(regJson.path("data").path("email").asText()).isEqualTo("flow@example.com");
		String access = regJson.path("data").path("access_token").asText();
		String refresh = regJson.path("data").path("refresh_token").asText();
		assertThat(access).isNotBlank();
		assertThat(refresh).isNotBlank();

		HttpHeaders headers = new HttpHeaders();
		headers.setBearerAuth(access);
		ResponseEntity<String> me = this.restTemplate.exchange(url("/me"), HttpMethod.GET, new HttpEntity<>(headers), String.class);
		assertThat(me.getStatusCode()).isEqualTo(HttpStatus.OK);
		JsonNode meJson = this.objectMapper.readTree(me.getBody());
		assertThat(meJson.path("data").path("email").asText()).isEqualTo("flow@example.com");
		assertThat(meJson.path("data").path("roles").get(0).asText()).isEqualTo("CANDIDATE");

		String refreshBody = "{\"refresh_token\":\"" + refresh + "\"}";
		ResponseEntity<String> ref = this.restTemplate.postForEntity(url("/refresh"), jsonEntity(refreshBody), String.class);
		assertThat(ref.getStatusCode()).isEqualTo(HttpStatus.OK);
		String newAccess = this.objectMapper.readTree(ref.getBody()).path("data").path("access_token").asText();
		assertThat(newAccess).isNotBlank();

		String loginBody = "{\"email\":\"flow@example.com\",\"password\":\"SecurePass123!\"}";
		ResponseEntity<String> login = this.restTemplate.postForEntity(url("/login"), jsonEntity(loginBody), String.class);
		assertThat(login.getStatusCode()).isEqualTo(HttpStatus.OK);
	}

	@Test
	void loginWithBadPasswordReturnsInvalidCredentials() throws Exception {
		String reg = """
				{"email":"bad@example.com","password":"SecurePass123!","first_name":"A","last_name":"B","role":"CANDIDATE"}
				""";
		assertThat(this.restTemplate.postForEntity(url("/register"), jsonEntity(reg), String.class).getStatusCode()).isEqualTo(HttpStatus.CREATED);

		String loginBody = "{\"email\":\"bad@example.com\",\"password\":\"WrongPassword1!\"}";
		ResponseEntity<String> res = this.restTemplate.postForEntity(url("/login"), jsonEntity(loginBody), String.class);
		assertThat(res.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
		JsonNode j = this.objectMapper.readTree(res.getBody());
		assertThat(j.path("error").path("code").asText()).isEqualTo("INVALID_CREDENTIALS");
	}

	@Test
	void duplicateEmailIs409() throws Exception {
		String reg = """
				{"email":"dup@example.com","password":"SecurePass123!","first_name":"A","last_name":"B","role":"CANDIDATE"}
				""";
		assertThat(this.restTemplate.postForEntity(url("/register"), jsonEntity(reg), String.class).getStatusCode()).isEqualTo(HttpStatus.CREATED);
		ResponseEntity<String> second = this.restTemplate.postForEntity(url("/register"), jsonEntity(reg), String.class);
		assertThat(second.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
		JsonNode j = this.objectMapper.readTree(second.getBody());
		assertThat(j.path("error").path("code").asText()).isEqualTo("EMAIL_ALREADY_REGISTERED");
	}

	@Test
	void adminPingRequiresAdminRole() throws Exception {
		String reg = """
				{"email":"cand@example.com","password":"SecurePass123!","first_name":"A","last_name":"B","role":"CANDIDATE"}
				""";
		ResponseEntity<String> r = this.restTemplate.postForEntity(url("/register"), jsonEntity(reg), String.class);
		assertThat(r.getStatusCode()).isEqualTo(HttpStatus.CREATED);
		String access = this.objectMapper.readTree(r.getBody()).path("data").path("access_token").asText();

		HttpHeaders headers = new HttpHeaders();
		headers.setBearerAuth(access);
		ResponseEntity<String> admin = this.restTemplate.exchange(url("/admin/ping"), HttpMethod.GET, new HttpEntity<>(headers), String.class);
		assertThat(admin.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
	}

	private static HttpEntity<String> jsonEntity(String body) {
		HttpHeaders h = new HttpHeaders();
		h.setContentType(MediaType.APPLICATION_JSON);
		return new HttpEntity<>(body, h);
	}
}
