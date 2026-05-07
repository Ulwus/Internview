package io.internview.interview_service.service;

import java.time.Instant;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.interview_service.media.MediaServiceClient;
import io.internview.interview_service.repository.InterviewSessionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class InterviewParticipationService {

	private final InterviewSessionRepository interviewSessionRepository;
	private final MediaServiceClient mediaServiceClient;

	@Transactional
	public void markExpertJoinedIfNeeded(UUID sessionId) {
		this.interviewSessionRepository.findById(sessionId).ifPresent(session -> {
			if (session.getExpertJoinedAt() == null) {
				session.setExpertJoinedAt(Instant.now());
				this.interviewSessionRepository.save(session);
			}
		});
	}

	/**
	 * Her iki katılımcı (candidate + expert) room'a join olduğunda,
	 * recording'i atomik şekilde claim edip media-service'te başlatmaya çalışır.
	 *
	 * <p>İdempotenttir: aynı oturum için tekrar tekrar çağrılabilir.
	 * DB-level guard ({@code recording_started_at IS NULL}) ile race condition önlenir.
	 *
	 * @param sessionId InterviewSession ID (mediasoup roomId ile aynı)
	 * @param peerCount join'den sonraki room peer sayısı (Redis'ten okunur)
	 */
	public void tryStartRecordingIfBothJoined(UUID sessionId, int peerCount) {
		if (peerCount < 2) {
			return;
		}

		Instant now = Instant.now();
		int claimed = this.interviewSessionRepository.tryClaimRecordingStart(sessionId, now);
		if (claimed == 0) {
			log.debug("Recording zaten başlatılmış veya oturum tamamlanmış: sessionId={}", sessionId);
			return;
		}

		try {
			this.mediaServiceClient.startRecording(sessionId.toString());
			log.info("Recording otomatik başlatıldı: sessionId={}", sessionId);
		}
		catch (Exception ex) {
			log.warn("Otomatik recording başlatılamadı, claim geri alınıyor: sessionId={} hata={}",
				sessionId, ex.getMessage());
			this.interviewSessionRepository.clearRecordingStartIfMatches(sessionId, now);
		}
	}
}
