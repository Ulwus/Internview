package io.internview.interview_service.web;

import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import io.internview.interview_service.domain.InterviewAnalysis;
import io.internview.interview_service.service.InterviewAnalysisService;
import io.internview.interview_service.web.dto.InterviewAnalysisReportResponse;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
public class InterviewAnalysisController {

	private final InterviewAnalysisService analysisService;

	@GetMapping({"/{sessionId}/report", "/sessions/{sessionId}/report"})
	public ResponseEntity<InterviewAnalysisReportResponse> getReport(
		@PathVariable UUID sessionId,
		@AuthenticationPrincipal Jwt jwt
	) {
		UUID userId = UUID.fromString(jwt.getSubject());
		InterviewAnalysis analysis = this.analysisService.getReportForParticipant(sessionId, userId);
		InterviewAnalysisReportResponse response = InterviewAnalysisReportResponse.builder()
			.sessionId(analysis.getSession().getId())
			.transcript(analysis.getTranscript())
			.analysis(this.analysisService.toApiAnalysis(analysis.getAnalysisResult()))
			.createdAt(analysis.getCreatedAt())
			.build();
		return ResponseEntity.ok(response);
	}
}
