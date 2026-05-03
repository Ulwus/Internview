package io.internview.interview_service.signaling;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Assumptions;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.client.WebSocketClient;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import io.internview.interview_service.domain.InterviewSession;
import io.internview.interview_service.repository.InterviewSessionRepository;
import io.internview.interview_service.support.JwtTestTokens;

/**
 * İki istemcili signaling doğrulaması. Redis için Testcontainers kullanılmaz:
 * {@code infrastructure} altında {@code docker compose up -d redis} (veya tam infra) gerekir.
 * <p>
 * Bağlantı adresi ortam değişkenleri: {@code REDIS_HOST} (varsayılan {@code localhost}),
 * {@code REDIS_PORT} (varsayılan {@code 6379}).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class SignalingWebSocketIntegrationTest {

	private static final String JWT_SECRET = "test-only-super-secret-change-me-test-only-super-secret-change-me";

	@DynamicPropertySource
	static void redisProperties(DynamicPropertyRegistry registry) {
		String host = System.getenv().getOrDefault("REDIS_HOST", "localhost");
		String portStr = System.getenv().getOrDefault("REDIS_PORT", "6379");
		registry.add("spring.data.redis.host", () -> host);
		registry.add("spring.data.redis.port", () -> portStr);
	}

	@BeforeAll
	static void assumeRedisReachable() {
		String host = System.getenv().getOrDefault("REDIS_HOST", "localhost");
		int port = Integer.parseInt(System.getenv().getOrDefault("REDIS_PORT", "6379"));
		Assumptions.assumeTrue(
			pingRedis(host, port),
			() -> "Redis erişilemiyor (%s:%d). Başlat: cd infrastructure && docker compose up -d redis".formatted(host, port));
	}

	private static boolean pingRedis(String host, int port) {
		try (Socket s = new Socket()) {
			s.connect(new InetSocketAddress(host, port), 1500);
			return true;
		}
		catch (IOException e) {
			return false;
		}
	}

	@LocalServerPort
	private int port;

	@Autowired
	private InterviewSessionRepository interviewSessionRepository;

	private UUID sessionId;
	private UUID candidateId;
	private UUID expertId;

	@BeforeEach
	void cleanAndSeed() {
		this.interviewSessionRepository.deleteAll();
		this.sessionId = UUID.randomUUID();
		this.candidateId = UUID.randomUUID();
		this.expertId = UUID.randomUUID();
		Instant now = Instant.now();
		InterviewSession session = InterviewSession.builder()
			.id(this.sessionId)
			.bookingId(UUID.randomUUID())
			.candidateId(this.candidateId)
			.expertId(this.expertId)
			.scheduledTime(now)
			.status("SCHEDULED")
			.createdAt(now)
			.updatedAt(now)
			.build();
		this.interviewSessionRepository.save(session);
	}

	@Test
	void twoPeers_offerForwarded() throws Exception {
		String candidateToken = JwtTestTokens.hs256Token(JWT_SECRET, this.candidateId, "CANDIDATE");
		String expertToken = JwtTestTokens.hs256Token(JWT_SECRET, this.expertId, "EXPERT");

		WebSocketClient client = new StandardWebSocketClient();
		BlockingQueue<String> expertIncoming = new LinkedBlockingQueue<>();

		WebSocketHttpHeaders expertHeaders = new WebSocketHttpHeaders();
		expertHeaders.add("Authorization", "Bearer " + expertToken);
		URI expertUri = URI.create(wsUrl(this.sessionId));
		WebSocketSession expertWs = client.execute(new TextWebSocketHandler() {
			@Override
			protected void handleTextMessage(WebSocketSession session, TextMessage message) {
				expertIncoming.offer(message.getPayload());
			}
		}, expertHeaders, expertUri).get(15, TimeUnit.SECONDS);

		WebSocketHttpHeaders candidateHeaders = new WebSocketHttpHeaders();
		candidateHeaders.add("Authorization", "Bearer " + candidateToken);
		URI candidateUri = URI.create(wsUrl(this.sessionId));
		WebSocketSession candidateWs = client.execute(new TextWebSocketHandler() {
			@Override
			protected void handleTextMessage(WebSocketSession session, TextMessage message) {
				// room joined / peer joined — ignore for this assertion
			}
		}, candidateHeaders, candidateUri).get(15, TimeUnit.SECONDS);

		String offerJson = """
			{"type":"OFFER","targetUserId":"%s","fromUserId":"%s","sdp":"v=0 test"}
			""".formatted(this.expertId, this.candidateId);
		candidateWs.sendMessage(new TextMessage(offerJson));

		String received = pollUntilContains(expertIncoming, "\"type\":\"OFFER\"", 15, TimeUnit.SECONDS);
		assertThat(received).isNotNull();
		assertThat(received).contains("\"sdp\":\"v=0 test\"");

		candidateWs.close();
		expertWs.close();
	}

	@Test
	void handshakeWithoutToken_fails() {
		WebSocketClient client = new StandardWebSocketClient();
		URI uri = URI.create(wsUrl(this.sessionId));
		assertThatThrownBy(() -> client.execute(new TextWebSocketHandler() {
		}, new WebSocketHttpHeaders(), uri).get(15, TimeUnit.SECONDS))
			.satisfies(ex -> {
				Throwable c = ex;
				while (c != null) {
					String m = c.getMessage() != null ? c.getMessage() : "";
					if (m.contains("401") || m.contains("Unauthorized") || m.contains("Handshake")) {
						return;
					}
					c = c.getCause();
				}
				throw new AssertionError("Beklenen handshake hatası yok: " + ex);
			});
	}

	private String wsUrl(UUID roomId) {
		return "ws://127.0.0.1:" + this.port + "/ws/signaling/" + roomId;
	}

	/** ROOM_JOINED / PEER_JOINED gibi mesajları atlayarak hedef substring'i arar. */
	private static String pollUntilContains(BlockingQueue<String> q, String needle, long timeout, TimeUnit unit)
		throws InterruptedException {
		long deadline = System.nanoTime() + unit.toNanos(timeout);
		while (System.nanoTime() < deadline) {
			String m = q.poll(200, TimeUnit.MILLISECONDS);
			if (m != null && m.contains(needle)) {
				return m;
			}
		}
		return null;
	}
}
