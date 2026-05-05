package io.internview.interview_service.media;

import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import io.internview.interview_service.media.dto.MediaServiceDtos.ConnectTransportRequest;
import io.internview.interview_service.media.dto.MediaServiceDtos.ConsumeRequest;
import io.internview.interview_service.media.dto.MediaServiceDtos.ConsumeResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.CreateRoomRequest;
import io.internview.interview_service.media.dto.MediaServiceDtos.CreateRoomResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.CreateTransportResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.ProduceRequest;
import io.internview.interview_service.media.dto.MediaServiceDtos.ProduceResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.RecordingStartResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.RecordingStopResponse;
import io.internview.interview_service.media.dto.MediaServiceDtos.RouterCapabilitiesResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Media Service (Mediasoup SFU) internal HTTP client.
 * <p>
 * Spring Boot RestClient kullanarak Node.js media-service API'sine
 * istek gönderir. Tüm endpoint'ler internal ağda çalışır.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class MediaServiceClient {

	private final RestClient mediaServiceRestClient;

	// ── Room (Router) ────────────────────────────────

	/**
	 * Yeni bir room (Mediasoup Router) oluşturur.
	 *
	 * @param roomId Room ID (genelde InterviewSession ID)
	 * @return RTP capabilities dahil room bilgisi
	 */
	public CreateRoomResponse createRoom(String roomId) {
		log.info("Media Service: Room oluşturuluyor: {}", roomId);
		return this.mediaServiceRestClient.post()
			.uri("/rooms")
			.body(CreateRoomRequest.builder().roomId(roomId).build())
			.retrieve()
			.body(CreateRoomResponse.class);
	}

	/**
	 * Router'ın RTP capabilities bilgisini getirir.
	 *
	 * @param roomId Room ID
	 * @return RTP capabilities
	 */
	public RouterCapabilitiesResponse getRouterCapabilities(String roomId) {
		return this.mediaServiceRestClient.get()
			.uri("/rooms/{roomId}/router-capabilities", roomId)
			.retrieve()
			.body(RouterCapabilitiesResponse.class);
	}

	/**
	 * Room'u kapatır.
	 *
	 * @param roomId Room ID
	 */
	public void closeRoom(String roomId) {
		log.info("Media Service: Room kapatılıyor: {}", roomId);
		this.mediaServiceRestClient.delete()
			.uri("/rooms/{roomId}", roomId)
			.retrieve()
			.toBodilessEntity();
	}

	// ── Transport ────────────────────────────────────

	/**
	 * WebRtcTransport oluşturur.
	 *
	 * @param roomId Room ID
	 * @return Transport parametreleri (ICE, DTLS bilgileri)
	 */
	public CreateTransportResponse createTransport(String roomId) {
		log.debug("Media Service: Transport oluşturuluyor (room={})", roomId);
		return this.mediaServiceRestClient.post()
			.uri("/rooms/{roomId}/transports", roomId)
			.retrieve()
			.body(CreateTransportResponse.class);
	}

	/**
	 * Transport'u bağlar (DTLS handshake).
	 *
	 * @param transportId Transport ID
	 * @param request DTLS parameters
	 */
	public void connectTransport(String transportId, ConnectTransportRequest request) {
		log.debug("Media Service: Transport bağlanıyor: {}", transportId);
		this.mediaServiceRestClient.post()
			.uri("/transports/{transportId}/connect", transportId)
			.body(request)
			.retrieve()
			.toBodilessEntity();
	}

	// ── Producer / Consumer ──────────────────────────

	/**
	 * Producer oluşturur (client → SFU).
	 *
	 * @param transportId Transport ID
	 * @param request kind + rtpParameters
	 * @return Producer bilgisi
	 */
	public ProduceResponse produce(String transportId, ProduceRequest request) {
		log.debug("Media Service: Produce (transport={}, kind={})", transportId, request.getKind());
		return this.mediaServiceRestClient.post()
			.uri("/transports/{transportId}/produce", transportId)
			.body(request)
			.retrieve()
			.body(ProduceResponse.class);
	}

	/**
	 * Consumer oluşturur (SFU → client).
	 *
	 * @param transportId Consumer transport ID
	 * @param request roomId, producerId, rtpCapabilities
	 * @return Consumer bilgisi
	 */
	public ConsumeResponse consume(String transportId, ConsumeRequest request) {
		log.debug("Media Service: Consume (transport={}, producer={})", transportId, request.getProducerId());
		return this.mediaServiceRestClient.post()
			.uri("/transports/{transportId}/consume", transportId)
			.body(request)
			.retrieve()
			.body(ConsumeResponse.class);
	}

	/**
	 * Consumer'ı resume eder.
	 *
	 * @param consumerId Consumer ID
	 */
	public void resumeConsumer(String consumerId) {
		log.debug("Media Service: Consumer resume: {}", consumerId);
		this.mediaServiceRestClient.post()
			.uri("/consumers/{consumerId}/resume", consumerId)
			.retrieve()
			.toBodilessEntity();
	}

	// ── Recording ────────────────────────────────────

	/**
	 * Server-side recording başlatır.
	 *
	 * @param roomId Room ID
	 * @return Recording durumu
	 */
	public RecordingStartResponse startRecording(String roomId) {
		log.info("Media Service: Recording başlatılıyor: {}", roomId);
		return this.mediaServiceRestClient.post()
			.uri("/rooms/{roomId}/recording/start", roomId)
			.retrieve()
			.body(RecordingStartResponse.class);
	}

	/**
	 * Server-side recording durdurur ve S3 URL döndürür.
	 *
	 * @param roomId Room ID
	 * @return Recording durumu ve S3 URL
	 */
	public RecordingStopResponse stopRecording(String roomId) {
		log.info("Media Server: Recording durduruluyor: {}", roomId);
		return this.mediaServiceRestClient.post()
			.uri("/rooms/{roomId}/recording/stop", roomId)
			.retrieve()
			.body(RecordingStopResponse.class);
	}
}
