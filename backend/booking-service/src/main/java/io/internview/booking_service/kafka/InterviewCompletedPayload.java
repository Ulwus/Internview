package io.internview.booking_service.kafka;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class InterviewCompletedPayload {

	@JsonProperty("booking_id")
	private UUID bookingId;

	@JsonProperty("session_id")
	private String sessionId;

	@JsonProperty("candidate_id")
	private UUID candidateId;

	@JsonProperty("expert_id")
	private UUID expertId;

	@JsonProperty("duration_seconds")
	private Long durationSeconds;

	@JsonProperty("recorded_video_url")
	private String recordedVideoUrl;
}

