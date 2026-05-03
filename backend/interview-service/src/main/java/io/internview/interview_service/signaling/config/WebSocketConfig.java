package io.internview.interview_service.signaling.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.lang.NonNull;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

import io.internview.interview_service.signaling.handler.SignalingWebSocketHandler;
import lombok.RequiredArgsConstructor;

@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketConfigurer {

	private final SignalingWebSocketHandler signalingWebSocketHandler;
	private final WebSocketJwtHandshakeInterceptor webSocketJwtHandshakeInterceptor;

	@Override
	public void registerWebSocketHandlers(@NonNull WebSocketHandlerRegistry registry) {
		registry.addHandler(this.signalingWebSocketHandler, "/ws/signaling/{roomId}")
			.addInterceptors(this.webSocketJwtHandshakeInterceptor)
			.setAllowedOriginPatterns("*");
	}
}
