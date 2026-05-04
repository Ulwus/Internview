package io.internview.interview_service.turn;

import java.util.List;

import lombok.Builder;
import lombok.Getter;

/**
 * Client'a döndürülen TURN/STUN credential bilgisi.
 * <p>
 * WebRTC RTCPeerConnection'ın iceServers yapılandırmasında kullanılır:
 * <pre>
 * new RTCPeerConnection({
 *   iceServers: [{
 *     urls: turnCredentials.urls,
 *     username: turnCredentials.username,
 *     credential: turnCredentials.credential
 *   }]
 * });
 * </pre>
 */
@Getter
@Builder
public class TurnCredentials {

	/**
	 * HMAC ile üretilmiş geçici kullanıcı adı.
	 * Format: "expireTimestamp:userId"
	 */
	private final String username;

	/**
	 * HMAC-SHA1 ile üretilmiş geçici credential.
	 */
	private final String credential;

	/**
	 * Credential geçerlilik süresi (saniye).
	 */
	private final long ttl;

	/**
	 * STUN/TURN server URL listesi.
	 */
	private final List<String> urls;
}
