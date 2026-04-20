package io.internview.booking_service;

import java.util.UUID;
import java.util.function.Supplier;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

import io.internview.booking_service.lock.BookingLockService;

/**
 * Testlerde Redis olmadığı için lock'u aynen action'ı çalıştıran
 * basit bir implementasyonla değiştiriyoruz.
 */
@TestConfiguration
public class TestBookingLockConfig {

	@Bean
	@Primary
	BookingLockService passthroughBookingLockService() {
		return new BookingLockService() {
			@Override
			public <T> T runWithSlotLock(UUID slotId, Supplier<T> action) {
				return action.get();
			}
		};
	}
}
