package io.internview.interview_service.signaling.authorization;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import io.internview.interview_service.domain.InterviewSession;
import io.internview.interview_service.repository.InterviewSessionRepository;
import io.internview.interview_service.signaling.error.SignalingException;

@ExtendWith(MockitoExtension.class)
class RoomAuthorizerTest {

	@Mock
	private InterviewSessionRepository interviewSessionRepository;

	@InjectMocks
	private RoomAuthorizer roomAuthorizer;

	@Test
	void returnsSessionWhenUserIsCandidate() {
		UUID roomId = UUID.randomUUID();
		UUID candidateId = UUID.randomUUID();
		UUID expertId = UUID.randomUUID();
		InterviewSession session = InterviewSession.builder()
			.id(roomId)
			.bookingId(UUID.randomUUID())
			.candidateId(candidateId)
			.expertId(expertId)
			.scheduledTime(Instant.now())
			.status("SCHEDULED")
			.build();
		when(this.interviewSessionRepository.findById(eq(roomId))).thenReturn(Optional.of(session));

		InterviewSession out = this.roomAuthorizer.assertParticipant(roomId, candidateId);
		assertThat(out.getId()).isEqualTo(roomId);
	}

	@Test
	void throwsWhenStranger() {
		UUID roomId = UUID.randomUUID();
		UUID stranger = UUID.randomUUID();
		InterviewSession session = InterviewSession.builder()
			.id(roomId)
			.bookingId(UUID.randomUUID())
			.candidateId(UUID.randomUUID())
			.expertId(UUID.randomUUID())
			.scheduledTime(Instant.now())
			.status("SCHEDULED")
			.build();
		when(this.interviewSessionRepository.findById(eq(roomId))).thenReturn(Optional.of(session));

		assertThatThrownBy(() -> this.roomAuthorizer.assertParticipant(roomId, stranger))
			.isInstanceOf(SignalingException.class)
			.hasFieldOrPropertyWithValue("code", "ROOM_FORBIDDEN");
	}

	@Test
	void throwsWhenSessionMissing() {
		UUID roomId = UUID.randomUUID();
		when(this.interviewSessionRepository.findById(eq(roomId))).thenReturn(Optional.empty());

		assertThatThrownBy(() -> this.roomAuthorizer.assertParticipant(roomId, UUID.randomUUID()))
			.isInstanceOf(SignalingException.class)
			.hasFieldOrPropertyWithValue("code", "SESSION_NOT_FOUND");
	}
}
