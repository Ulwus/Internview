package io.internview.user_service.kafka;

import java.math.BigDecimal;

import com.fasterxml.jackson.databind.ObjectMapper;

import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import io.internview.user_service.domain.ExpertProfile;
import io.internview.user_service.domain.User;
import io.internview.user_service.domain.UserRole;
import io.internview.user_service.repository.ExpertProfileRepository;
import io.internview.user_service.repository.UserRepository;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class ExpertRatingEventsConsumer {

	private final ExpertProfileRepository expertProfileRepository;
	private final UserRepository userRepository;

	private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

	@KafkaListener(topics = "${internview.kafka.topics.expert-rating-events}", groupId = "${spring.kafka.consumer.group-id:user-service}")
	@Transactional
	public void onMessage(String rawJson) throws Exception {
		ExpertRatingUpdatedEventMessage message = OBJECT_MAPPER.readValue(rawJson, ExpertRatingUpdatedEventMessage.class);
		if (message == null || !"EXPERT_RATING_UPDATED".equalsIgnoreCase(message.getEventType())) {
			return;
		}
		if (message.getPayload() == null || message.getPayload().getExpertUserId() == null) {
			return;
		}

		BigDecimal avg = message.getPayload().getAverageRating() != null ? message.getPayload().getAverageRating() : BigDecimal.ZERO;

		ExpertProfile profile = expertProfileRepository.findByUserId(message.getPayload().getExpertUserId()).orElse(null);
		if (profile == null) {
			// Profil henüz oluşturulmadıysa, ilgili kullanıcı EXPERT ise minimal bir profil oluştur.
			User user = userRepository.findById(message.getPayload().getExpertUserId()).orElse(null);
			if (user == null || user.getRole() != UserRole.EXPERT) {
				return;
			}
			profile = ExpertProfile.builder()
				.id(java.util.UUID.randomUUID())
				.user(user)
				.yearsOfExperience(0)
				.currency("USD")
				.averageRating(avg)
				.totalSessions(0)
				.isVerified(false)
				.isAvailable(true)
				.skills(new java.util.HashSet<>())
				.build();
		} else {
			profile.setAverageRating(avg);
		}

		expertProfileRepository.save(profile);
	}
}

