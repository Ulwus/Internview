package io.internview.interview_service.signaling.service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import io.internview.interview_service.signaling.model.RoomPeerInfo;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class RedisRoomRegistry {

	private final StringRedisTemplate redisTemplate;

	@Value("${internview.signaling.redis.key-prefix:signaling}")
	private String keyPrefix;

	@Value("${internview.signaling.room.ttl-seconds:7200}")
	private long roomTtlSeconds;

	private String roomKey(UUID roomId) {
		return this.keyPrefix + ":room:" + roomId;
	}

	public List<RoomPeerInfo> listPeers(UUID roomId) {
		Map<Object, Object> entries = this.redisTemplate.opsForHash().entries(this.roomKey(roomId));
		List<RoomPeerInfo> out = new ArrayList<>(entries.size());
		for (Map.Entry<Object, Object> e : entries.entrySet()) {
			UUID userId = UUID.fromString(e.getKey().toString());
			String role = parseRole(e.getValue().toString());
			out.add(new RoomPeerInfo(userId, role));
		}
		return out;
	}

	public void addPeer(UUID roomId, UUID userId, String role) {
		String key = this.roomKey(roomId);
		String value = role + "|" + Instant.now();
		this.redisTemplate.opsForHash().put(key, userId.toString(), value);
		this.redisTemplate.expire(key, java.time.Duration.ofSeconds(this.roomTtlSeconds));
	}

	public void removePeer(UUID roomId, UUID userId) {
		String key = this.roomKey(roomId);
		this.redisTemplate.opsForHash().delete(key, userId.toString());
		Long size = this.redisTemplate.opsForHash().size(key);
		if (size != null && size == 0) {
			this.redisTemplate.delete(key);
		}
	}

	private static String parseRole(String stored) {
		int pipe = stored.indexOf('|');
		return pipe > 0 ? stored.substring(0, pipe) : stored;
	}
}
