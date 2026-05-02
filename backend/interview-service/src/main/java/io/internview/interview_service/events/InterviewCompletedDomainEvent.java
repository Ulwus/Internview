package io.internview.interview_service.events;

import java.util.UUID;

public record InterviewCompletedDomainEvent(
	UUID sessionId,
	UUID bookingId,
	UUID candidateId,
	UUID expertId,
	long durationSeconds,
	String recordedVideoUrl
) {}

