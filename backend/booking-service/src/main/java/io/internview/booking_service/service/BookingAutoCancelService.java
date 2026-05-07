package io.internview.booking_service.service;

import java.time.Instant;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.booking_service.domain.Booking;
import io.internview.booking_service.domain.BookingStatus;
import io.internview.booking_service.repository.BookingRepository;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class BookingAutoCancelService {

	private final BookingRepository bookingRepository;
	private final InterviewServiceClient interviewServiceClient;

	/**
	 * scheduled_end geçtiyse ve uzman o görüşmenin herhangi bir anında odaya girmediyse CANCELLED.
	 */
	@Transactional
	public int cancelIfExpertNeverJoined(Instant now) {
		int cancelled = 0;
		for (Booking b : bookingRepository.findConfirmedEndedBefore(now)) {
			UUID bookingId = b.getId();
			if (interviewServiceClient.expertEverJoined(bookingId)) {
				continue;
			}
			b.setStatus(BookingStatus.CANCELLED);
			bookingRepository.save(b);
			cancelled++;
		}
		return cancelled;
	}
}

