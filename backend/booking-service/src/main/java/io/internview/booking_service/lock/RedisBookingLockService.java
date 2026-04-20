package io.internview.booking_service.lock;

import java.time.Duration;
import java.util.UUID;
import java.util.function.Supplier;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Redis {@code SET key value NX EX ttl} primitifi ile uygulanan lock.
 *
 * <p>Not: Kısa TTL + "release only if owner" kontrolü sayesinde düğüm çökmesi
 * durumunda lock otomatik serbest kalır ve başka bir istekçinin yanlışlıkla
 * lock'u düşürmesi engellenir.
 */
@Component
@ConditionalOnBean(StringRedisTemplate.class)
public class RedisBookingLockService implements BookingLockService {

	private static final String LOCK_KEY_PREFIX = "booking:slot:lock:";
	private static final String RELEASE_SCRIPT = """
		if redis.call('get', KEYS[1]) == ARGV[1] then
			return redis.call('del', KEYS[1])
		else
			return 0
		end
		""";

	private final StringRedisTemplate redis;
	private final Duration ttl;

	public RedisBookingLockService(
		StringRedisTemplate redis,
		@Value("${booking.lock.ttl-seconds:15}") long ttlSeconds
	) {
		this.redis = redis;
		this.ttl = Duration.ofSeconds(ttlSeconds);
	}

	@Override
	public <T> T runWithSlotLock(UUID slotId, Supplier<T> action) {
		String key = LOCK_KEY_PREFIX + slotId;
		String token = UUID.randomUUID().toString();
		Boolean acquired = redis.opsForValue().setIfAbsent(key, token, ttl);
		if (acquired == null || !acquired) {
			throw new SlotLockedException(slotId);
		}
		try {
			return action.get();
		} finally {
			releaseSafely(key, token);
		}
	}

	private void releaseSafely(String key, String token) {
		try {
			redis.execute(connection -> connection.scriptingCommands().eval(
				RELEASE_SCRIPT.getBytes(),
				org.springframework.data.redis.connection.ReturnType.INTEGER,
				1,
				key.getBytes(),
				token.getBytes()
			), true);
		} catch (RuntimeException ignored) {
			// Lock TTL üzerinden zaten düşecek; release hatası istekçiyi etkilemesin.
		}
	}
}
