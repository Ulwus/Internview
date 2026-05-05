package io.internview.interview_service.media.dto;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Media Service API DTO'ları.
 * <p>
 * Bu sınıf, media-service (Mediasoup Node.js) ile interview-service
 * arasındaki internal HTTP API iletişiminde kullanılan veri yapılarını tanımlar.
 */
public final class MediaServiceDtos {

	private MediaServiceDtos() {}

	// ── Room ──────────────────────────────────────────

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class CreateRoomRequest {
		private String roomId;
	}

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class CreateRoomResponse {
		private String roomId;
		private Object rtpCapabilities;
	}

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class RouterCapabilitiesResponse {
		private Object rtpCapabilities;
	}

	// ── Transport ─────────────────────────────────────

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class CreateTransportResponse {
		private String id;
		private Object iceParameters;
		private List<Object> iceCandidates;
		private Object dtlsParameters;
	}

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class ConnectTransportRequest {
		private Object dtlsParameters;
	}

	// ── Producer ──────────────────────────────────────

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class ProduceRequest {
		private String kind;
		private Object rtpParameters;
	}

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class ProduceResponse {
		private String id;
		private String kind;
		private Object rtpParameters;
	}

	// ── Consumer ──────────────────────────────────────

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class ConsumeRequest {
		private String roomId;
		private String producerId;
		private Object rtpCapabilities;
	}

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class ConsumeResponse {
		private String id;
		private String producerId;
		private String kind;
		private Object rtpParameters;
	}

	// ── Consumer Resume ───────────────────────────────

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class ResumeResponse {
		private boolean resumed;
	}

	// ── Recording ─────────────────────────────────────

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class RecordingStartResponse {
		private boolean recording;
		private String roomId;
	}

	@Data
	@Builder
	@NoArgsConstructor
	@AllArgsConstructor
	@JsonIgnoreProperties(ignoreUnknown = true)
	public static class RecordingStopResponse {
		private boolean recording;
		private String roomId;
		private String recordedVideoUrl;
	}
}
