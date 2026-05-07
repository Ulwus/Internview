package io.internview.user_service.kafka;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExpertRatingUpdatedEventMessage {
	private String eventType;
	private ExpertRatingUpdatedPayload payload;
}

