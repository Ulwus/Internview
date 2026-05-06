package io.internview.interview_service.signaling.config;

import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;

import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;

import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class WebSocketJwtHandshakeInterceptor implements HandshakeInterceptor {

	public static final String ATTR_USER_ID = "userId";
	public static final String ATTR_ROLE = "role";
	public static final String ATTR_ROOM_ID = "roomId";

	private static final String PREFIX = "/ws/signaling/";

	private final JwtDecoder jwtDecoder;

	@Override
	public boolean beforeHandshake(
		ServerHttpRequest request,
		ServerHttpResponse response,
		WebSocketHandler wsHandler,
		Map<String, Object> attributes
	) {
		String token = extractBearerToken(request);
		if (token == null || token.isBlank()) {
			token = extractQueryToken(request);
		}
		if (token == null || token.isBlank()) {
			response.setStatusCode(HttpStatus.UNAUTHORIZED);
			return false;
		}
		try {
			Jwt jwt = this.jwtDecoder.decode(token.trim());
			attributes.put(ATTR_USER_ID, UUID.fromString(jwt.getSubject()));
			attributes.put(ATTR_ROLE, jwt.getClaimAsString("role"));
			attributes.put(ATTR_ROOM_ID, parseRoomId(request));
		}
		catch (Exception ex) {
			response.setStatusCode(HttpStatus.UNAUTHORIZED);
			return false;
		}
		return true;
	}

	@Override
	public void afterHandshake(
		ServerHttpRequest request,
		ServerHttpResponse response,
		WebSocketHandler wsHandler,
		Exception exception
	) {
		// no-op
	}

	private static String extractBearerToken(ServerHttpRequest request) {
		String auth = request.getHeaders().getFirst("Authorization");
		if (auth == null || !auth.regionMatches(true, 0, "Bearer ", 0, 7)) {
			return null;
		}
		return auth.substring(7).trim();
	}

	private static String extractQueryToken(ServerHttpRequest request) {
		if (request instanceof ServletServerHttpRequest servletRequest) {
			String q = servletRequest.getServletRequest().getParameter("token");
			return q != null ? q.trim() : null;
		}
		String query = request.getURI().getQuery();
		if (query == null || query.isBlank()) {
			return null;
		}
		for (String part : query.split("&")) {
			int eq = part.indexOf('=');
			if (eq > 0 && "token".equals(part.substring(0, eq))) {
				return part.substring(eq + 1).trim();
			}
		}
		return null;
	}

	private static UUID parseRoomId(ServerHttpRequest request) {
		String path = request.getURI().getPath();
		if (path == null || !path.startsWith(PREFIX)) {
			throw new IllegalArgumentException("Geçersiz signaling path: " + path);
		}
		String idPart = path.substring(PREFIX.length());
		int q = idPart.indexOf('?');
		if (q >= 0) {
			idPart = idPart.substring(0, q);
		}
		if (idPart.endsWith("/")) {
			idPart = idPart.substring(0, idPart.length() - 1);
		}
		return UUID.fromString(idPart);
	}
}
