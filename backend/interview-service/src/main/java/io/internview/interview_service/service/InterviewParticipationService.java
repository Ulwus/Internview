package io.internview.interview_service.service;

import java.time.Instant;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.interview_service.repository.InterviewSessionRepository;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class InterviewParticipationService {

	private final InterviewSessionRepository interviewSessionRepository;

	@Transactional
	public void markExpertJoinedIfNeeded(UUID sessionId) {
		this.interviewSessionRepository.findById(sessionId).ifPresent(session -> {
			if (session.getExpertJoinedAt() == null) {
				session.setExpertJoinedAt(Instant.now());
				this.interviewSessionRepository.save(session);
			}
		});
	}
}

