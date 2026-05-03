package io.internview.interview_service.signaling.model;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record RoomPeerInfo(UUID userId, String role) {
}
