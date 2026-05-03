package io.internview.interview_service.signaling.authorization;

import java.util.UUID;

import org.springframework.stereotype.Component;

import io.internview.interview_service.domain.InterviewSession;
import io.internview.interview_service.repository.InterviewSessionRepository;
import io.internview.interview_service.signaling.error.SignalingException;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class RoomAuthorizer {

	private final InterviewSessionRepository interviewSessionRepository;

	/**
	 * roomId = interview_sessions.id (session UUID).
	 */
	public InterviewSession assertParticipant(UUID roomId, UUID userId) {
		InterviewSession session = this.interviewSessionRepository.findById(roomId)
			.orElseThrow(() -> new SignalingException("SESSION_NOT_FOUND", "Mülakat oturumu bulunamadı: " + roomId));

		if (!session.getCandidateId().equals(userId) && !session.getExpertId().equals(userId)) {
			throw new SignalingException("ROOM_FORBIDDEN", "Bu odaya erişim yetkiniz yok.");
		}
		return session;
	}
}
