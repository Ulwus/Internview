package io.internview.interview_service.web;

import java.util.List;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
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

import io.internview.interview_service.domain.InterviewSession;
import io.internview.interview_service.service.InterviewSessionService;
import io.internview.interview_service.turn.TurnCredentialService;
import io.internview.interview_service.turn.TurnCredentials;
import io.internview.interview_service.web.dto.CompleteSessionRequest;
import io.internview.interview_service.web.dto.IceServer;
import io.internview.interview_service.web.dto.SessionSummaryResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/sessions")
@RequiredArgsConstructor
public class InterviewSessionController {

	private final InterviewSessionService interviewSessionService;
	private final TurnCredentialService turnCredentialService;

	@Value("${internview.signaling.ws-base-url:ws://localhost:8080}")
	private String signalingWsBaseUrl;

	@GetMapping("/booking/{bookingId}")
	public ResponseEntity<SessionSummaryResponse> getSessionByBooking(
		@PathVariable UUID bookingId,
		@AuthenticationPrincipal Jwt jwt
	) {
		UUID userId = UUID.fromString(jwt.getSubject());
		InterviewSession session = this.interviewSessionService.getByBookingForParticipant(bookingId, userId);
		String wsUrl = this.signalingWsBaseUrl.replaceAll("/$", "") + "/ws/signaling/" + session.getId();

		// TURN/STUN credential üret
		TurnCredentials turnCreds = this.turnCredentialService.generateCredentials(userId);
		IceServer iceServer = IceServer.builder()
			.urls(turnCreds.getUrls())
			.username(turnCreds.getUsername())
			.credential(turnCreds.getCredential())
			.build();

		SessionSummaryResponse body = SessionSummaryResponse.builder()
			.sessionId(session.getId())
			.bookingId(session.getBookingId())
			.candidateId(session.getCandidateId())
			.expertId(session.getExpertId())
			.status(session.getStatus())
			.signalingWebSocketUrl(wsUrl)
			.iceServers(List.of(iceServer))
			.build();
		return ResponseEntity.ok(body);
	}

	@PostMapping("/{bookingId}/complete")
	@PreAuthorize("hasRole('EXPERT')")
	public ResponseEntity<InterviewSession> complete(
		@PathVariable UUID bookingId,
		@Valid @RequestBody CompleteSessionRequest request
	) {
		InterviewSession completed = this.interviewSessionService.completeByBookingId(
			bookingId,
			request.getDurationSeconds(),
			request.getRecordedVideoUrl()
		);
		return ResponseEntity.status(HttpStatus.OK).body(completed);
	}
}


