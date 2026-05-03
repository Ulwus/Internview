package io.internview.interview_service.signaling.handler;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import com.fasterxml.jackson.databind.ObjectMapper;

import io.internview.interview_service.signaling.config.WebSocketJwtHandshakeInterceptor;
import io.internview.interview_service.signaling.error.SignalingException;
import io.internview.interview_service.signaling.model.SignalingMessage;
import io.internview.interview_service.signaling.service.RoomService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Component
@RequiredArgsConstructor
@Slf4j
public class SignalingWebSocketHandler extends TextWebSocketHandler {

	private final RoomService roomService;
	private final ObjectMapper objectMapper;

	@Override
	public void afterConnectionEstablished(@NonNull WebSocketSession session) throws Exception {
		UUID roomId = (UUID) session.getAttributes().get(WebSocketJwtHandshakeInterceptor.ATTR_ROOM_ID);
		UUID userId = (UUID) session.getAttributes().get(WebSocketJwtHandshakeInterceptor.ATTR_USER_ID);
		String role = (String) session.getAttributes().get(WebSocketJwtHandshakeInterceptor.ATTR_ROLE);
		try {
			this.roomService.joinRoom(roomId, userId, role, session);
		}
		catch (SignalingException ex) {
			this.sendError(session, ex.getCode(), ex.getMessage());
			session.close(CloseStatus.POLICY_VIOLATION.withReason(ex.getCode()));
		}
	}

	@Override
	protected void handleTextMessage(@NonNull WebSocketSession session, @NonNull TextMessage message) throws Exception {
		byte[] raw = message.getPayload().getBytes(StandardCharsets.UTF_8);
		this.roomService.assertPayloadSize(raw);

		UUID roomId = (UUID) session.getAttributes().get(WebSocketJwtHandshakeInterceptor.ATTR_ROOM_ID);
		UUID userId = (UUID) session.getAttributes().get(WebSocketJwtHandshakeInterceptor.ATTR_USER_ID);

		SignalingMessage parsed;
		try {
			parsed = this.objectMapper.readValue(message.getPayload(), SignalingMessage.class);
		}
		catch (Exception ex) {
			this.sendError(session, "INVALID_JSON", "Mesaj çözümlenemedi.");
			return;
		}

		try {
			switch (parsed) {
				case SignalingMessage.OfferMessage offer -> this.roomService.handleOffer(roomId, userId, offer);
				case SignalingMessage.AnswerMessage answer -> this.roomService.handleAnswer(roomId, userId, answer);
				case SignalingMessage.IceCandidateMessage ice -> this.roomService.handleIceCandidate(roomId, userId, ice);
				case SignalingMessage.LeaveRoomMessage() -> session.close(CloseStatus.NORMAL);
				case SignalingMessage.RoomJoinedMessage ignoredJoined -> this.sendError(session, "INVALID_MESSAGE",
					"Bu mesaj tipi istemciden kabul edilmez.");
				case SignalingMessage.PeerJoinedMessage ignoredPeerJoined -> this.sendError(session, "INVALID_MESSAGE",
					"Bu mesaj tipi istemciden kabul edilmez.");
				case SignalingMessage.PeerLeftMessage ignoredPeerLeft -> this.sendError(session, "INVALID_MESSAGE",
					"Bu mesaj tipi istemciden kabul edilmez.");
				case SignalingMessage.ErrorMessage ignoredErr -> this.sendError(session, "INVALID_MESSAGE",
					"Bu mesaj tipi istemciden kabul edilmez.");
			}
		}
		catch (SignalingException ex) {
			this.sendError(session, ex.getCode(), ex.getMessage());
		}
	}

	@Override
	public void afterConnectionClosed(@NonNull WebSocketSession session, @NonNull CloseStatus status) {
		UUID roomId = (UUID) session.getAttributes().get(WebSocketJwtHandshakeInterceptor.ATTR_ROOM_ID);
		UUID userId = (UUID) session.getAttributes().get(WebSocketJwtHandshakeInterceptor.ATTR_USER_ID);
		if (roomId != null && userId != null) {
			try {
				this.roomService.leaveRoom(roomId, userId);
			}
			catch (Exception ex) {
				log.debug("leaveRoom: {}", ex.getMessage());
			}
		}
	}

	private void sendError(WebSocketSession session, String code, String msg) throws IOException {
		if (!session.isOpen()) {
			return;
		}
		String json = this.objectMapper.writeValueAsString(new SignalingMessage.ErrorMessage(code, msg));
		session.sendMessage(new TextMessage(json));
	}
}
