package io.internview.interview_service.web;

import java.util.Map;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.internview.interview_service.repository.InterviewSessionRepository;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/sessions")
@RequiredArgsConstructor
public class ExpertJoinedController {

	private final InterviewSessionRepository interviewSessionRepository;

	@GetMapping("/booking/{bookingId}/expert-joined")
	public ResponseEntity<Map<String, Boolean>> expertJoined(@PathVariable UUID bookingId) {
		return interviewSessionRepository.findByBookingId(bookingId)
			.map(s -> ResponseEntity.ok(Map.of("expertJoined", s.getExpertJoinedAt() != null)))
			.orElseGet(() -> ResponseEntity.notFound().build());
	}
}

