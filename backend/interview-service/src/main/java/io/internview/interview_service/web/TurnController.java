package io.internview.interview_service.web;

import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.internview.interview_service.turn.TurnCredentialService;
import io.internview.interview_service.turn.TurnCredentials;
import lombok.RequiredArgsConstructor;

/**
 * TURN/STUN credential endpoint'i.
 * <p>
 * Client'lar WebRTC bağlantısı kurarken bu endpoint'ten
 * geçici HMAC-based TURN credential alır.
 */
@RestController
@RequestMapping("/turn")
@RequiredArgsConstructor
public class TurnController {

	private final TurnCredentialService turnCredentialService;

	/**
	 * Authenticated kullanıcı için TURN credential üretir.
	 *
	 * @param jwt  Kullanıcının JWT token'ı
	 * @return TURN credential bilgisi (username, credential, ttl, urls)
	 */
	@GetMapping("/credentials")
	public ResponseEntity<TurnCredentials> getCredentials(@AuthenticationPrincipal Jwt jwt) {
		UUID userId = UUID.fromString(jwt.getSubject());
		TurnCredentials credentials = this.turnCredentialService.generateCredentials(userId);
		return ResponseEntity.ok(credentials);
	}
}
