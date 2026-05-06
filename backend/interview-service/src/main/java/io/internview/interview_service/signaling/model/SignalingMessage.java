package io.internview.interview_service.signaling.model;

import java.util.List;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

@JsonIgnoreProperties(ignoreUnknown = true)
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({
	@JsonSubTypes.Type(value = SignalingMessage.OfferMessage.class, name = "OFFER"),
	@JsonSubTypes.Type(value = SignalingMessage.AnswerMessage.class, name = "ANSWER"),
	@JsonSubTypes.Type(value = SignalingMessage.IceCandidateMessage.class, name = "ICE_CANDIDATE"),
	@JsonSubTypes.Type(value = SignalingMessage.LeaveRoomMessage.class, name = "LEAVE_ROOM"),
	@JsonSubTypes.Type(value = SignalingMessage.RoomJoinedMessage.class, name = "ROOM_JOINED"),
	@JsonSubTypes.Type(value = SignalingMessage.PeerJoinedMessage.class, name = "PEER_JOINED"),
	@JsonSubTypes.Type(value = SignalingMessage.PeerLeftMessage.class, name = "PEER_LEFT"),
	@JsonSubTypes.Type(value = SignalingMessage.ErrorMessage.class, name = "ERROR"),
	@JsonSubTypes.Type(value = SignalingMessage.FinishRequestMessage.class, name = "FINISH_REQUEST"),
	@JsonSubTypes.Type(value = SignalingMessage.FinishAcceptMessage.class, name = "FINISH_ACCEPT"),
	@JsonSubTypes.Type(value = SignalingMessage.FinishRejectMessage.class, name = "FINISH_REJECT"),
	@JsonSubTypes.Type(value = SignalingMessage.FinishDoneMessage.class, name = "FINISH_DONE")
})
@JsonInclude(JsonInclude.Include.NON_NULL)
public sealed interface SignalingMessage permits SignalingMessage.OfferMessage, SignalingMessage.AnswerMessage,
	SignalingMessage.IceCandidateMessage, SignalingMessage.LeaveRoomMessage, SignalingMessage.RoomJoinedMessage,
	SignalingMessage.PeerJoinedMessage, SignalingMessage.PeerLeftMessage, SignalingMessage.ErrorMessage,
	SignalingMessage.FinishRequestMessage, SignalingMessage.FinishAcceptMessage, SignalingMessage.FinishRejectMessage,
	SignalingMessage.FinishDoneMessage {

	record OfferMessage(UUID targetUserId, UUID fromUserId, String sdp) implements SignalingMessage {
	}

	record AnswerMessage(UUID targetUserId, UUID fromUserId, String sdp) implements SignalingMessage {
	}

	record IceCandidateMessage(
		UUID targetUserId,
		UUID fromUserId,
		String candidate,
		String sdpMid,
		Integer sdpMLineIndex
	) implements SignalingMessage {
	}

	record LeaveRoomMessage() implements SignalingMessage {
	}

	record RoomJoinedMessage(List<RoomPeerInfo> peers) implements SignalingMessage {
	}

	record PeerJoinedMessage(UUID userId, String role) implements SignalingMessage {
	}

	record PeerLeftMessage(UUID userId) implements SignalingMessage {
	}

	record ErrorMessage(String code, String message) implements SignalingMessage {
	}

	record FinishRequestMessage(UUID targetUserId, UUID fromUserId) implements SignalingMessage {
	}

	record FinishAcceptMessage(UUID targetUserId, UUID fromUserId) implements SignalingMessage {
	}

	record FinishRejectMessage(UUID targetUserId, UUID fromUserId) implements SignalingMessage {
	}

	record FinishDoneMessage(UUID targetUserId, UUID fromUserId) implements SignalingMessage {
	}
}
