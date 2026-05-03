package io.internview.interview_service.signaling.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import io.internview.interview_service.signaling.authorization.RoomAuthorizer;
import io.internview.interview_service.signaling.error.SignalingException;

@ExtendWith(MockitoExtension.class)
class RoomServiceTest {

	@Mock
	private RoomAuthorizer roomAuthorizer;

	@Mock
	private RedisRoomRegistry redisRoomRegistry;

	private final ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());

	@InjectMocks
	private RoomService roomService;

	@BeforeEach
	void maxPayload() {
		ReflectionTestUtils.setField(this.roomService, "objectMapper", this.objectMapper);
		ReflectionTestUtils.setField(this.roomService, "maxPayloadBytes", 128);
	}

	@Test
	void assertPayloadSizeThrowsWhenOverLimit() {
		byte[] huge = new byte[256];
		assertThatThrownBy(() -> this.roomService.assertPayloadSize(huge))
			.isInstanceOf(SignalingException.class)
			.hasFieldOrPropertyWithValue("code", "PAYLOAD_TOO_LARGE");
	}

	@Test
	void assertPayloadSizeAllowsWithinLimit() {
		this.roomService.assertPayloadSize(new byte[64]);
	}
}
