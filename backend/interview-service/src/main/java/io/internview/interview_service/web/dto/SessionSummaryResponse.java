package io.internview.interview_service.web.dto;

import java.util.List;
import java.util.UUID;

import lombok.Builder;

@Builder
public record SessionSummaryResponse(
	UUID sessionId,
	UUID bookingId,
	UUID candidateId,
	UUID expertId,
	String status,
	String signalingWebSocketUrl,
	List<IceServer> iceServers
) {
}
