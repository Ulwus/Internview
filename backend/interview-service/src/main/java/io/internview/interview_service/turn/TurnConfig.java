package io.internview.interview_service.turn;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

import lombok.Getter;
import lombok.Setter;

/**
 * Coturn TURN/STUN sunucu yapılandırma property'leri.
 * <p>
 * HMAC-based time-limited credential üretimi için gerekli
 * shared secret, TTL ve STUN/TURN URL listesini tutar.
 */
@Configuration
@ConfigurationProperties(prefix = "internview.turn")
@Getter
@Setter
public class TurnConfig {

	/**
	 * Coturn ile paylaşılan HMAC secret.
	 * turnserver.conf dosyasındaki "static-auth-secret" ile aynı olmalıdır.
	 */
	private String secret = "internview_turn_secret";

	/**
	 * Credential geçerlilik süresi (saniye). Varsayılan: 24 saat.
	 */
	private long ttlSeconds = 86400;

	/**
	 * STUN/TURN server URL listesi.
	 * Örn: ["stun:localhost:3478", "turn:localhost:3478"]
	 */
	private List<String> urls = List.of("stun:localhost:3478", "turn:localhost:3478");
}
