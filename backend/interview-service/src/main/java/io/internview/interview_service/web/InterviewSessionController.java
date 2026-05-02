package io.internview.interview_service.web;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.internview.interview_service.domain.InterviewSession;
import io.internview.interview_service.service.InterviewSessionService;
import io.internview.interview_service.web.dto.CompleteSessionRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/sessions")
@RequiredArgsConstructor
public class InterviewSessionController {

	private final InterviewSessionService interviewSessionService;

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

