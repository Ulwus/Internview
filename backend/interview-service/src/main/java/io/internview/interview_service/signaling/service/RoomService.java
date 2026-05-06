package io.internview.interview_service.signaling.service;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import com.fasterxml.jackson.databind.ObjectMapper;

import io.internview.interview_service.signaling.authorization.RoomAuthorizer;
import io.internview.interview_service.signaling.error.SignalingException;
import io.internview.interview_service.signaling.model.RoomPeerInfo;
import io.internview.interview_service.signaling.model.SignalingMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class RoomService {

	private final RoomAuthorizer roomAuthorizer;
	private final RedisRoomRegistry redisRoomRegistry;
	private final ObjectMapper objectMapper;

	@Value("${internview.signaling.message.max-payload-bytes:65536}")
	private int maxPayloadBytes;

	/** roomId -> (userId -> WebSocketSession) — aynı pod içi iletişim */
	private final Map<UUID, Map<UUID, WebSocketSession>> localRooms = new ConcurrentHashMap<>();

	public void joinRoom(UUID roomId, UUID userId, String role, WebSocketSession session) throws IOException {
		this.roomAuthorizer.assertParticipant(roomId, userId);

		List<RoomPeerInfo> peersBefore = this.redisRoomRegistry.listPeers(roomId);
		List<RoomPeerInfo> others = peersBefore.stream().filter(p -> !p.userId().equals(userId)).toList();

		this.redisRoomRegistry.addPeer(roomId, userId, role);
		this.localRooms.computeIfAbsent(roomId, r -> new ConcurrentHashMap<>()).put(userId, session);

		this.send(session, new SignalingMessage.RoomJoinedMessage(others));

		SignalingMessage.PeerJoinedMessage announcement = new SignalingMessage.PeerJoinedMessage(userId, role);
		this.broadcastExcept(roomId, userId, announcement);
	}

	public void leaveRoom(UUID roomId, UUID userId) {
		Map<UUID, WebSocketSession> room = this.localRooms.get(roomId);
		if (room != null) {
			room.remove(userId);
			if (room.isEmpty()) {
				this.localRooms.remove(roomId);
			}
		}
		this.redisRoomRegistry.removePeer(roomId, userId);
		this.broadcastExcept(roomId, userId, new SignalingMessage.PeerLeftMessage(userId));
	}

	public void handleOffer(UUID roomId, UUID fromUserId, SignalingMessage.OfferMessage msg) throws IOException {
		if (msg.targetUserId() == null) {
			this.sendErrorTo(fromUserId, roomId, "INVALID_MESSAGE", "targetUserId gerekli");
			return;
		}
		this.roomAuthorizer.assertParticipant(roomId, fromUserId);
		SignalingMessage forward = new SignalingMessage.OfferMessage(null, fromUserId, msg.sdp());
		this.forwardToPeer(roomId, fromUserId, msg.targetUserId(), forward);
	}

	public void handleAnswer(UUID roomId, UUID fromUserId, SignalingMessage.AnswerMessage msg) throws IOException {
		if (msg.targetUserId() == null) {
			this.sendErrorTo(fromUserId, roomId, "INVALID_MESSAGE", "targetUserId gerekli");
			return;
		}
		this.roomAuthorizer.assertParticipant(roomId, fromUserId);
		SignalingMessage forward = new SignalingMessage.AnswerMessage(null, fromUserId, msg.sdp());
		this.forwardToPeer(roomId, fromUserId, msg.targetUserId(), forward);
	}

	public void handleIceCandidate(UUID roomId, UUID fromUserId, SignalingMessage.IceCandidateMessage msg) throws IOException {
		if (msg.targetUserId() == null) {
			this.sendErrorTo(fromUserId, roomId, "INVALID_MESSAGE", "targetUserId gerekli");
			return;
		}
		this.roomAuthorizer.assertParticipant(roomId, fromUserId);
		SignalingMessage forward = new SignalingMessage.IceCandidateMessage(
			null,
			fromUserId,
			msg.candidate(),
			msg.sdpMid(),
			msg.sdpMLineIndex()
		);
		this.forwardToPeer(roomId, fromUserId, msg.targetUserId(), forward);
	}

	public void handleFinishRequest(UUID roomId, UUID fromUserId, SignalingMessage.FinishRequestMessage msg) throws IOException {
		if (msg.targetUserId() == null) {
			this.sendErrorTo(fromUserId, roomId, "INVALID_MESSAGE", "targetUserId gerekli");
			return;
		}
		this.roomAuthorizer.assertParticipant(roomId, fromUserId);
		SignalingMessage forward = new SignalingMessage.FinishRequestMessage(null, fromUserId);
		this.forwardToPeer(roomId, fromUserId, msg.targetUserId(), forward);
	}

	public void handleFinishAccept(UUID roomId, UUID fromUserId, SignalingMessage.FinishAcceptMessage msg) throws IOException {
		if (msg.targetUserId() == null) {
			this.sendErrorTo(fromUserId, roomId, "INVALID_MESSAGE", "targetUserId gerekli");
			return;
		}
		this.roomAuthorizer.assertParticipant(roomId, fromUserId);
		SignalingMessage forward = new SignalingMessage.FinishAcceptMessage(null, fromUserId);
		this.forwardToPeer(roomId, fromUserId, msg.targetUserId(), forward);
	}

	public void handleFinishReject(UUID roomId, UUID fromUserId, SignalingMessage.FinishRejectMessage msg) throws IOException {
		if (msg.targetUserId() == null) {
			this.sendErrorTo(fromUserId, roomId, "INVALID_MESSAGE", "targetUserId gerekli");
			return;
		}
		this.roomAuthorizer.assertParticipant(roomId, fromUserId);
		SignalingMessage forward = new SignalingMessage.FinishRejectMessage(null, fromUserId);
		this.forwardToPeer(roomId, fromUserId, msg.targetUserId(), forward);
	}

	public void handleFinishDone(UUID roomId, UUID fromUserId, SignalingMessage.FinishDoneMessage msg) throws IOException {
		if (msg.targetUserId() == null) {
			this.sendErrorTo(fromUserId, roomId, "INVALID_MESSAGE", "targetUserId gerekli");
			return;
		}
		this.roomAuthorizer.assertParticipant(roomId, fromUserId);
		SignalingMessage forward = new SignalingMessage.FinishDoneMessage(null, fromUserId);
		this.forwardToPeer(roomId, fromUserId, msg.targetUserId(), forward);
	}

	public void assertPayloadSize(byte[] payload) {
		if (payload != null && payload.length > this.maxPayloadBytes) {
			throw new SignalingException("PAYLOAD_TOO_LARGE", "Mesaj boyutu sınırı aşıldı.");
		}
	}

	private void forwardToPeer(UUID roomId, UUID fromUserId, UUID targetUserId, SignalingMessage forward) throws IOException {
		Map<UUID, WebSocketSession> room = this.localRooms.get(roomId);
		if (room == null) {
			this.sendErrorTo(fromUserId, roomId, "PEER_NOT_CONNECTED", "Hedef kullanıcı bu sunucuda bağlı değil.");
			return;
		}
		WebSocketSession target = room.get(targetUserId);
		if (target == null || !target.isOpen()) {
			this.sendErrorTo(fromUserId, roomId, "PEER_NOT_CONNECTED", "Hedef kullanıcı bağlı değil.");
			return;
		}
		this.send(target, forward);
	}

	private void sendErrorTo(UUID userId, UUID roomId, String code, String message) throws IOException {
		Map<UUID, WebSocketSession> room = this.localRooms.get(roomId);
		if (room == null) {
			return;
		}
		WebSocketSession s = room.get(userId);
		if (s != null && s.isOpen()) {
			this.send(s, new SignalingMessage.ErrorMessage(code, message));
		}
	}

	private void broadcastExcept(UUID roomId, UUID excludeUserId, SignalingMessage message) {
		Map<UUID, WebSocketSession> room = this.localRooms.get(roomId);
		if (room == null) {
			return;
		}
		for (Map.Entry<UUID, WebSocketSession> e : room.entrySet()) {
			if (e.getKey().equals(excludeUserId)) {
				continue;
			}
			WebSocketSession ws = e.getValue();
			if (ws.isOpen()) {
				try {
					this.send(ws, message);
				}
				catch (IOException ex) {
					log.debug("broadcastExcept gönderilemedi: {}", ex.getMessage());
				}
			}
		}
	}

	private void send(WebSocketSession session, SignalingMessage message) throws IOException {
		String json = this.objectMapper.writeValueAsString(message);
		session.sendMessage(new TextMessage(json));
	}
}
