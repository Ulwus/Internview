package io.internview.interview_service.events;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class InterviewCompletedPayload {

	@JsonProperty("session_id")
	UUID sessionId;

	@JsonProperty("booking_id")
	UUID bookingId;

	@JsonProperty("candidate_id")
	UUID candidateId;

	@JsonProperty("expert_id")
	UUID expertId;

	@JsonProperty("duration_seconds")
	long durationSeconds;

	@JsonProperty("recorded_video_url")
	String recordedVideoUrl;
}

