package io.internview.interview_service.web.dto;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class InterviewAnalysisReportResponse {
	UUID sessionId;
	String transcript;
	Map<String, Object> analysis;
	Instant createdAt;
}
