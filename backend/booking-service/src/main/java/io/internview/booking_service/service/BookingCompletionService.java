package io.internview.booking_service.service;

import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.booking_service.domain.Booking;
import io.internview.booking_service.domain.BookingStatus;
import io.internview.booking_service.repository.BookingRepository;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class BookingCompletionService {

	private final BookingRepository bookingRepository;

	@Transactional
	public void markCompletedFromInterview(UUID bookingId) {
		Booking booking = bookingRepository.findById(bookingId).orElse(null);
		if (booking == null) {
			return;
		}
		// Zaten terminal statüdeyse dokunma
		if (booking.getStatus() == BookingStatus.COMPLETED || booking.getStatus() == BookingStatus.CANCELLED) {
			return;
		}
		// PENDING durumda complete etmeyelim; uzman onayı olmadan görüşme olmamalı.
		if (booking.getStatus() != BookingStatus.CONFIRMED) {
			return;
		}
		booking.setStatus(BookingStatus.COMPLETED);
		bookingRepository.save(booking);
	}
}

