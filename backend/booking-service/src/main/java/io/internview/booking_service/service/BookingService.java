package io.internview.booking_service.service;

import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.booking_service.domain.AvailabilitySlot;
import io.internview.booking_service.domain.Booking;
import io.internview.booking_service.domain.BookingStatus;
import io.internview.booking_service.error.BookingNotFoundException;
import io.internview.booking_service.error.InvalidBookingStateException;
import io.internview.booking_service.error.InvalidSlotException;
import io.internview.booking_service.error.SlotAlreadyBookedException;
import io.internview.booking_service.error.SlotNotFoundException;
import io.internview.booking_service.lock.BookingLockService;
import io.internview.booking_service.repository.AvailabilitySlotRepository;
import io.internview.booking_service.repository.BookingRepository;
import io.internview.booking_service.web.dto.BookingResponse;
import io.internview.booking_service.web.dto.CreateBookingRequest;
import io.internview.booking_service.web.dto.PageResponse;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class BookingService {

	private static final Set<BookingStatus> ACTIVE_STATUSES = EnumSet.of(BookingStatus.PENDING, BookingStatus.CONFIRMED);

	private final BookingRepository bookingRepository;
	private final AvailabilitySlotRepository slotRepository;
	private final BookingLockService lockService;

	@Transactional
	public BookingResponse createBooking(UUID candidateId, CreateBookingRequest request) {
		UUID slotId = request.getSlotId();
		UUID expertId = request.getExpertId();
		return this.lockService.runWithSlotLock(slotId, () -> createBookingLocked(candidateId, expertId, slotId));
	}

	private BookingResponse createBookingLocked(UUID candidateId, UUID expertId, UUID slotId) {
		AvailabilitySlot slot = this.slotRepository.findById(slotId)
			.orElseThrow(() -> new SlotNotFoundException("Slot bulunamadı: " + slotId));

		if (!slot.getExpertId().equals(expertId)) {
			throw new InvalidSlotException("Slot verilen uzmana ait değil");
		}
		if (slot.isBooked()) {
			throw new SlotAlreadyBookedException("Slot zaten rezerve edilmiş: " + slotId);
		}
		if (this.bookingRepository.existsBySlotIdAndStatusIn(slotId, ACTIVE_STATUSES)) {
			throw new SlotAlreadyBookedException("Slot zaten aktif rezervasyon içeriyor: " + slotId);
		}

		Booking booking = Booking.builder()
			.candidateId(candidateId)
			.expertId(expertId)
			.slotId(slotId)
			.status(BookingStatus.CONFIRMED)
			.scheduledStart(slot.getStartTime())
			.scheduledEnd(slot.getEndTime())
			.build();
		Booking saved = this.bookingRepository.save(booking);

		slot.setBooked(true);
		this.slotRepository.save(slot);

		return BookingResponse.from(saved);
	}

	@Transactional(readOnly = true)
	public BookingResponse getById(UUID bookingId, UUID viewerId) {
		Booking booking = this.bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BookingNotFoundException("Booking bulunamadı: " + bookingId));
		if (!booking.getCandidateId().equals(viewerId) && !booking.getExpertId().equals(viewerId)) {
			throw new BookingNotFoundException("Booking bulunamadı: " + bookingId);
		}
		return BookingResponse.from(booking);
	}

	@Transactional(readOnly = true)
	public PageResponse<BookingResponse> listForCandidate(UUID candidateId, int page, int size) {
		Pageable pageable = PageRequest.of(page, size);
		Page<BookingResponse> result = this.bookingRepository
			.findByCandidateIdOrderByScheduledStartDesc(candidateId, pageable)
			.map(BookingResponse::from);
		return PageResponse.from(result);
	}

	@Transactional(readOnly = true)
	public PageResponse<BookingResponse> listForExpert(UUID expertId, int page, int size) {
		Pageable pageable = PageRequest.of(page, size);
		Page<BookingResponse> result = this.bookingRepository
			.findByExpertIdOrderByScheduledStartDesc(expertId, pageable)
			.map(BookingResponse::from);
		return PageResponse.from(result);
	}

	@Transactional
	public BookingResponse updateStatus(UUID bookingId, UUID actorId, BookingStatus next) {
		Booking booking = this.bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BookingNotFoundException("Booking bulunamadı: " + bookingId));

		if (!booking.getCandidateId().equals(actorId) && !booking.getExpertId().equals(actorId)) {
			throw new BookingNotFoundException("Booking bulunamadı: " + bookingId);
		}
		if (!booking.getStatus().canTransitionTo(next)) {
			throw new InvalidBookingStateException(
				"Geçersiz durum geçişi: " + booking.getStatus() + " -> " + next);
		}

		booking.setStatus(next);
		Booking saved = this.bookingRepository.save(booking);

		if (next == BookingStatus.CANCELLED) {
			this.slotRepository.findById(saved.getSlotId()).ifPresent(slot -> {
				slot.setBooked(false);
				this.slotRepository.save(slot);
			});
		}

		return BookingResponse.from(saved);
	}
}
