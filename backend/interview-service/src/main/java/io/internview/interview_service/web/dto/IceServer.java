package io.internview.interview_service.web.dto;

import java.util.List;

import lombok.Builder;
import lombok.Getter;

/**
 * Client'a dönülen ICE server bilgisi.
 * WebRTC RTCPeerConnection yapılandırmasında kullanılır.
 */
@Getter
@Builder
public class IceServer {

	/**
	 * STUN/TURN server URL listesi.
	 * Örn: ["stun:host:3478", "turn:host:3478"]
	 */
	private final List<String> urls;

	/**
	 * HMAC ile üretilmiş geçici kullanıcı adı (TURN için).
	 * STUN sunucuları için null olabilir.
	 */
	private final String username;

	/**
	 * HMAC-SHA1 ile üretilmiş geçici credential (TURN için).
	 * STUN sunucuları için null olabilir.
	 */
	private final String credential;
}
