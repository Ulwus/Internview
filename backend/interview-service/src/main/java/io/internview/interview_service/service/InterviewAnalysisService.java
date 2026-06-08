package io.internview.interview_service.service;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import io.internview.interview_service.domain.InterviewAnalysis;
import io.internview.interview_service.repository.InterviewAnalysisRepository;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class InterviewAnalysisService {

	private final InterviewAnalysisRepository analysisRepository;
	private final InterviewSessionService sessionService;

	@Transactional(readOnly = true)
	public InterviewAnalysis getReportForParticipant(UUID sessionId, UUID userId) {
		this.sessionService.getByIdForParticipant(sessionId, userId);
		return this.analysisRepository.findBySessionId(sessionId)
			.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Analiz raporu henüz hazır değil."));
	}

	public Map<String, Object> toApiAnalysis(Map<String, Object> storedAnalysis) {
		Map<String, Object> api = new LinkedHashMap<>();
		storedAnalysis.forEach((key, value) -> api.put(toCamelCase(key), value));
		return api;
	}

	private String toCamelCase(String key) {
		StringBuilder builder = new StringBuilder();
		boolean upperNext = false;
		for (char ch : key.toCharArray()) {
			if (ch == '_') {
				upperNext = true;
				continue;
			}
			builder.append(upperNext ? Character.toUpperCase(ch) : ch);
			upperNext = false;
		}
		return builder.toString();
	}
}
