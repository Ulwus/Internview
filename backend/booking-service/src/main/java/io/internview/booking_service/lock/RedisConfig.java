package io.internview.booking_service.lock;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;

@Configuration
public class RedisConfig {

	@Bean
	@ConditionalOnMissingBean(RedisConnectionFactory.class)
	RedisConnectionFactory redisConnectionFactory(
		@Value("${spring.data.redis.host:localhost}") String host,
		@Value("${spring.data.redis.port:6379}") int port
	) {
		return new LettuceConnectionFactory(new RedisStandaloneConfiguration(host, port));
	}

	@Bean
	@ConditionalOnMissingBean(StringRedisTemplate.class)
	StringRedisTemplate stringRedisTemplate(RedisConnectionFactory connectionFactory) {
		return new StringRedisTemplate(connectionFactory);
	}

	@Bean
	@ConditionalOnMissingBean(BookingLockService.class)
	BookingLockService bookingLockService(
		StringRedisTemplate redis,
		@Value("${booking.lock.ttl-seconds:15}") long ttlSeconds
	) {
		return new RedisBookingLockService(redis, ttlSeconds);
	}
}
