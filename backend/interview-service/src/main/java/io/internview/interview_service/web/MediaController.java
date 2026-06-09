package io.internview.interview_service.web;

import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import jakarta.servlet.http.HttpServletRequest;

import io.internview.interview_service.domain.InterviewSession;
import io.internview.interview_service.media.MediaServiceClient;
import io.internview.interview_service.media.dto.MediaServiceDtos.ConnectTransportRequest;
import io.internview.interview_service.media.dto.MediaServiceDtos.ConsumeRequest;
import io.internview.interview_service.media.dto.MediaServiceDtos.ConsumeResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.CreateTransportResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.ProduceRequest;
import io.internview.interview_service.media.dto.MediaServiceDtos.ProduceResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.ProducerListResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.RecordingStartResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.RecordingStopResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.RouterCapabilitiesResponse;
import io.internview.interview_service.repository.InterviewSessionRepository;

import lombok.RequiredArgsConstructor;

/**
 * Mediasoup media signaling proxy controller.
 * <p>
 * Client'lar bu endpoint'ler aracılığıyla media-service ile etkileşir.
 * Her istek önce interview session yetkilendirmesinden geçer,
 * ardından media-service'e proxy edilir.
 */
@RestController
@RequestMapping("/sessions/{sessionId}/media")
@RequiredArgsConstructor
public class MediaController {

	private final MediaServiceClient mediaServiceClient;
	private final InterviewSessionRepository sessionRepository;

	// ── Router Capabilities ──────────────────────────

	/**
	 * Room'un RTP capabilities bilgisini döndürür.
	 * Client, bu bilgiyi mediasoup-client Device.load() için kullanır.
	 */
	@GetMapping("/capabilities")
	public ResponseEntity<RouterCapabilitiesResponse> getCapabilities(
		@PathVariable UUID sessionId,
		@AuthenticationPrincipal Jwt jwt
	) {
		InterviewSession session = this.assertParticipant(sessionId, jwt);
		RouterCapabilitiesResponse response = this.mediaServiceClient
			.getRouterCapabilities(session.getId().toString());
		return ResponseEntity.ok(response);
	}

	// ── Transport ────────────────────────────────────

	/**
	 * WebRtcTransport oluşturur (send veya receive transport).
	 */
	@PostMapping("/transport")
	public ResponseEntity<CreateTransportResponse> createTransport(
		@PathVariable UUID sessionId,
		@AuthenticationPrincipal Jwt jwt,
		@RequestBody(required = false) Map<String, Object> body,
		HttpServletRequest request
	) {
		InterviewSession session = this.assertParticipant(sessionId, jwt);
		CreateTransportResponse response = this.mediaServiceClient
			.createTransport(session.getId().toString(), clientAnnouncedIp(body, request));
		return ResponseEntity.status(HttpStatus.CREATED).body(response);
	}

	/**
	 * Transport'u bağlar (DTLS handshake).
	 */
	@PostMapping("/transport/{transportId}/connect")
	public ResponseEntity<Void> connectTransport(
		@PathVariable UUID sessionId,
		@PathVariable String transportId,
		@RequestBody ConnectTransportRequest request,
		@AuthenticationPrincipal Jwt jwt
	) {
		this.assertParticipant(sessionId, jwt);
		this.mediaServiceClient.connectTransport(transportId, request);
		return ResponseEntity.ok().build();
	}

	// ── Producer / Consumer ──────────────────────────

	/**
	 * Producer oluşturur (client → SFU medya gönderimi).
	 */
	@PostMapping("/transport/{transportId}/produce")
	public ResponseEntity<ProduceResponse> produce(
		@PathVariable UUID sessionId,
		@PathVariable String transportId,
		@RequestBody ProduceRequest request,
		@AuthenticationPrincipal Jwt jwt
	) {
		this.assertParticipant(sessionId, jwt);
		ProduceResponse response = this.mediaServiceClient.produce(transportId, request);
		return ResponseEntity.status(HttpStatus.CREATED).body(response);
	}

	@GetMapping("/producers")
	public ResponseEntity<ProducerListResponse> listProducers(
		@PathVariable UUID sessionId,
		@AuthenticationPrincipal Jwt jwt
	) {
		InterviewSession session = this.assertParticipant(sessionId, jwt);
		ProducerListResponse response = this.mediaServiceClient.listProducers(session.getId().toString());
		return ResponseEntity.ok(response);
	}

	/**
	 * Consumer oluşturur (SFU → client medya alımı).
	 */
	@PostMapping("/transport/{transportId}/consume")
	public ResponseEntity<ConsumeResponse> consume(
		@PathVariable UUID sessionId,
		@PathVariable String transportId,
		@RequestBody ConsumeRequest request,
		@AuthenticationPrincipal Jwt jwt
	) {
		InterviewSession session = this.assertParticipant(sessionId, jwt);
		// roomId olarak session ID'sini set et
		request.setRoomId(session.getId().toString());
		ConsumeResponse response = this.mediaServiceClient.consume(transportId, request);
		return ResponseEntity.status(HttpStatus.CREATED).body(response);
	}

	/**
	 * Consumer'ı resume eder.
	 */
	@PostMapping("/consumer/{consumerId}/resume")
	public ResponseEntity<Void> resumeConsumer(
		@PathVariable UUID sessionId,
		@PathVariable String consumerId,
		@AuthenticationPrincipal Jwt jwt
	) {
		this.assertParticipant(sessionId, jwt);
		this.mediaServiceClient.resumeConsumer(consumerId);
		return ResponseEntity.ok().build();
	}

	// ── Recording ────────────────────────────────────

	/**
	 * Server-side recording başlatır.
	 * Yalnızca EXPERT rolü kullanabilir.
	 */
	@PostMapping("/recording/start")
	@PreAuthorize("hasRole('EXPERT')")
	public ResponseEntity<RecordingStartResponse> startRecording(
		@PathVariable UUID sessionId,
		@AuthenticationPrincipal Jwt jwt
	) {
		InterviewSession session = this.assertParticipant(sessionId, jwt);
		RecordingStartResponse response = this.mediaServiceClient
			.startRecording(session.getId().toString());
		return ResponseEntity.status(HttpStatus.CREATED).body(response);
	}

	/**
	 * Server-side recording durdurur ve S3 URL'sini döndürür.
	 * Yalnızca EXPERT rolü kullanabilir.
	 */
	@PostMapping("/recording/stop")
	@PreAuthorize("hasRole('EXPERT')")
	public ResponseEntity<RecordingStopResponse> stopRecording(
		@PathVariable UUID sessionId,
		@AuthenticationPrincipal Jwt jwt
	) {
		InterviewSession session = this.assertParticipant(sessionId, jwt);
		RecordingStopResponse response = this.mediaServiceClient
			.stopRecording(session.getId().toString());
		return ResponseEntity.ok(response);
	}

	// ── Yardımcı ─────────────────────────────────────

	/**
	 * Kullanıcının bu session'a katılımcı olduğunu doğrular.
	 */
	private InterviewSession assertParticipant(UUID sessionId, Jwt jwt) {
		UUID userId = UUID.fromString(jwt.getSubject());
		InterviewSession session = this.sessionRepository.findById(sessionId)
			.orElseThrow(() -> new ResponseStatusException(
				HttpStatus.NOT_FOUND, "Mülakat oturumu bulunamadı."));

		if (!session.getCandidateId().equals(userId)
			&& !session.getExpertId().equals(userId)) {
			throw new ResponseStatusException(
				HttpStatus.FORBIDDEN, "Bu oturuma erişim yetkiniz yok.");
		}
		return session;
	}

	private String clientVisibleHost(HttpServletRequest request) {
		String host = firstHeaderValue(request.getHeader("X-Forwarded-Host"));
		if (host == null || host.isBlank()) {
			host = request.getHeader("Host");
		}
		if (host == null || host.isBlank()) {
			return null;
		}

		host = host.trim();
		if (host.startsWith("[")) {
			int end = host.indexOf(']');
			return end > 0 ? host.substring(1, end) : null;
		}

		int colon = host.indexOf(':');
		if (colon > 0) {
			host = host.substring(0, colon);
		}

		if (!host.matches("[A-Za-z0-9.-]+")) {
			return null;
		}
		return host;
	}

	private String clientAnnouncedIp(Map<String, Object> body, HttpServletRequest request) {
		if (body != null) {
			Object value = body.get("announcedIp");
			if (value instanceof String announcedIp && !announcedIp.isBlank()) {
				String clean = cleanHost(announcedIp);
				if (clean != null) {
					return clean;
				}
			}
		}
		return clientVisibleHost(request);
	}

	private String cleanHost(String host) {
		host = host.trim();
		if (host.startsWith("[")) {
			int end = host.indexOf(']');
			return end > 0 ? host.substring(1, end) : null;
		}

		int colon = host.indexOf(':');
		if (colon > 0) {
			host = host.substring(0, colon);
		}

		if (!host.matches("[A-Za-z0-9.-]+")) {
			return null;
		}
		return host;
	}

	private String firstHeaderValue(String value) {
		if (value == null) {
			return null;
		}
		int comma = value.indexOf(',');
		return comma >= 0 ? value.substring(0, comma).trim() : value.trim();
	}
}
