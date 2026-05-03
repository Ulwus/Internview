package io.internview.interview_service.signaling;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import io.internview.interview_service.signaling.model.RoomPeerInfo;
import io.internview.interview_service.signaling.model.SignalingMessage;

class SignalingMessageSerializationTest {

	private ObjectMapper mapper;

	@BeforeEach
	void setUp() {
		this.mapper = new ObjectMapper();
		this.mapper.registerModule(new JavaTimeModule());
	}

	@Test
	void offerRoundTrip() throws Exception {
		UUID target = UUID.randomUUID();
		UUID from = UUID.randomUUID();
		SignalingMessage original = new SignalingMessage.OfferMessage(target, from, "v=0\r\no=-");
		String json = this.mapper.writeValueAsString(original);
		SignalingMessage parsed = this.mapper.readValue(json, SignalingMessage.class);
		assertThat(parsed).isInstanceOf(SignalingMessage.OfferMessage.class);
		SignalingMessage.OfferMessage o = (SignalingMessage.OfferMessage) parsed;
		assertThat(o.targetUserId()).isEqualTo(target);
		assertThat(o.fromUserId()).isEqualTo(from);
		assertThat(o.sdp()).isEqualTo("v=0\r\no=-");
	}

	@Test
	void iceCandidateRoundTrip() throws Exception {
		UUID t = UUID.randomUUID();
		UUID f = UUID.randomUUID();
		SignalingMessage original = new SignalingMessage.IceCandidateMessage(t, f, "candidate:1", "0", 0);
		String json = this.mapper.writeValueAsString(original);
		SignalingMessage parsed = this.mapper.readValue(json, SignalingMessage.class);
		assertThat(parsed).isInstanceOf(SignalingMessage.IceCandidateMessage.class);
		SignalingMessage.IceCandidateMessage ice = (SignalingMessage.IceCandidateMessage) parsed;
		assertThat(ice.sdpMLineIndex()).isZero();
	}

	@Test
	void roomJoinedWithPeers() throws Exception {
		UUID u = UUID.randomUUID();
		SignalingMessage original = new SignalingMessage.RoomJoinedMessage(
			List.of(new RoomPeerInfo(u, "CANDIDATE"))
		);
		String json = this.mapper.writeValueAsString(original);
		SignalingMessage parsed = this.mapper.readValue(json, SignalingMessage.class);
		assertThat(parsed).isInstanceOf(SignalingMessage.RoomJoinedMessage.class);
		assertThat(((SignalingMessage.RoomJoinedMessage) parsed).peers()).hasSize(1);
	}

	@Test
	void leaveRoomEmptyObject() throws Exception {
		SignalingMessage original = new SignalingMessage.LeaveRoomMessage();
		String json = this.mapper.writeValueAsString(original);
		SignalingMessage parsed = this.mapper.readValue(json, SignalingMessage.class);
		assertThat(parsed).isInstanceOf(SignalingMessage.LeaveRoomMessage.class);
	}
}
