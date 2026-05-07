package io.internview.booking_service.scheduler;

import java.time.Instant;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import io.internview.booking_service.service.BookingAutoCancelService;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class BookingAutoCancelScheduler {

	private final BookingAutoCancelService bookingAutoCancelService;

	@Scheduled(fixedDelayString = "${internview.booking.auto-cancel.delay-ms:60000}")
	public void run() {
		bookingAutoCancelService.cancelIfExpertNeverJoined(Instant.now());
	}
}

