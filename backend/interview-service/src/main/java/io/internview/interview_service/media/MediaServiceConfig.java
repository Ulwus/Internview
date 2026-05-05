package io.internview.interview_service.media;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

/**
 * Media Service (Mediasoup SFU) bağlantı yapılandırması.
 * <p>
 * Spring Boot 4.x RestClient kullanarak media-service internal
 * HTTP API'sine bağlantı sağlar.
 */
@Configuration
public class MediaServiceConfig {

	@Value("${internview.media-service.base-url:http://localhost:3000}")
	private String mediaServiceBaseUrl;

	@Bean
	RestClient mediaServiceRestClient() {
		return RestClient.builder()
			.baseUrl(this.mediaServiceBaseUrl)
			.build();
	}
}
