package io.internview.booking_service.service;

import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

@Component
public class InterviewServiceClient {

	private final RestClient restClient;

	public InterviewServiceClient(@Value("${internview.interview-service.base-url:http://localhost:8083}") String baseUrl) {
		this.restClient = RestClient.builder().baseUrl(baseUrl).build();
	}

	public boolean expertEverJoined(UUID bookingId) {
		try {
			Map<?, ?> res = this.restClient.get()
				.uri("/sessions/booking/{bookingId}/expert-joined", bookingId)
				.retrieve()
				.body(Map.class);
			if (res == null) return false;
			Object v = res.get("expertJoined");
			return Boolean.TRUE.equals(v);
		}
		catch (HttpClientErrorException e) {
			if (e.getStatusCode() == HttpStatus.NOT_FOUND) {
				return false;
			}
			throw e;
		}
	}
}

