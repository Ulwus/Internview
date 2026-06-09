package io.internview.booking_service.service;

import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;

import java.math.BigDecimal;
import java.math.RoundingMode;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.booking_service.domain.AvailabilitySlot;
import io.internview.booking_service.domain.Booking;
import io.internview.booking_service.domain.BookingStatus;
import io.internview.booking_service.events.BookingCreatedDomainEvent;
import io.internview.booking_service.events.ExpertRatingUpdatedDomainEvent;
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
	private final ApplicationEventPublisher eventPublisher;

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
			// Aday talebi: uzman onayı bekler.
			.status(BookingStatus.PENDING)
			.scheduledStart(slot.getStartTime())
			.scheduledEnd(slot.getEndTime())
			.build();
		Booking saved = this.bookingRepository.save(booking);

		// Slot, talep aşamasında da diğer adaylara kapanır.
		slot.setBooked(true);
		this.slotRepository.save(slot);

		return BookingResponse.from(saved);
	}

	@Transactional
	public BookingResponse approve(UUID bookingId, UUID expertId) {
		Booking booking = this.bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BookingNotFoundException("Booking bulunamadı: " + bookingId));
		if (!booking.getExpertId().equals(expertId)) {
			throw new BookingNotFoundException("Booking bulunamadı: " + bookingId);
		}
		if (booking.getStatus() != BookingStatus.PENDING) {
			throw new InvalidBookingStateException("Sadece PENDING booking onaylanabilir");
		}
		// Slot bazlı lock ile state geçişini atomik yap.
		return this.lockService.runWithSlotLock(booking.getSlotId(), () -> approveLocked(bookingId));
	}

	private BookingResponse approveLocked(UUID bookingId) {
		Booking booking = this.bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BookingNotFoundException("Booking bulunamadı: " + bookingId));
		if (booking.getStatus() != BookingStatus.PENDING) {
			throw new InvalidBookingStateException("Sadece PENDING booking onaylanabilir");
		}
		booking.setStatus(BookingStatus.CONFIRMED);
		Booking saved = this.bookingRepository.save(booking);

		// Interview-service (ve diğerleri) için event'i onay anında yayınla.
		this.eventPublisher.publishEvent(new BookingCreatedDomainEvent(
			saved.getId(),
			saved.getCandidateId(),
			saved.getExpertId(),
			saved.getSlotId(),
			saved.getScheduledStart(),
			saved.getStatus().name()
		));

		return BookingResponse.from(saved);
	}

	@Transactional
	public BookingResponse reject(UUID bookingId, UUID expertId) {
		Booking booking = this.bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BookingNotFoundException("Booking bulunamadı: " + bookingId));
		if (!booking.getExpertId().equals(expertId)) {
			throw new BookingNotFoundException("Booking bulunamadı: " + bookingId);
		}
		if (booking.getStatus() != BookingStatus.PENDING) {
			throw new InvalidBookingStateException("Sadece PENDING booking reddedilebilir");
		}
		booking.setStatus(BookingStatus.CANCELLED);
		Booking saved = this.bookingRepository.save(booking);

		// Slot tekrar açılır.
		this.slotRepository.findById(saved.getSlotId()).ifPresent(slot -> {
			slot.setBooked(false);
			this.slotRepository.save(slot);
		});

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
		// Candidate, CONFIRMED/COMPLETED geçişlerini doğrudan yapamasın; CONFIRMED sadece expert approve ile.
		if (booking.getCandidateId().equals(actorId) && next == BookingStatus.CONFIRMED) {
			throw new InvalidBookingStateException("Aday booking'i onaylayamaz");
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

	@Transactional
	public BookingResponse updateExpertFeedback(UUID bookingId, UUID expertId, Integer rating, String comment) {
		Booking booking = this.bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BookingNotFoundException("Booking bulunamadı: " + bookingId));

		if (!booking.getExpertId().equals(expertId)) {
			throw new BookingNotFoundException("Booking bulunamadı: " + bookingId);
		}
		if (booking.getStatus() != BookingStatus.COMPLETED) {
			throw new InvalidBookingStateException("Geri bildirim sadece COMPLETED randevuda verilebilir");
		}

		booking.setExpertToCandidateRating(rating);
		booking.setExpertToCandidateComment(comment != null && !comment.isBlank() ? comment.trim() : null);
		// Legacy alanları da dolduralım (geri uyumluluk / eski client'lar).
		booking.setExpertRating(rating);
		booking.setExpertComment(comment != null && !comment.isBlank() ? comment.trim() : null);
		return BookingResponse.from(this.bookingRepository.save(booking));
	}

	@Transactional
	public BookingResponse updateCandidateFeedback(UUID bookingId, UUID candidateId, Integer rating, String comment) {
		Booking booking = this.bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BookingNotFoundException("Booking bulunamadı: " + bookingId));

		if (!booking.getCandidateId().equals(candidateId)) {
			throw new BookingNotFoundException("Booking bulunamadı: " + bookingId);
		}
		if (booking.getStatus() != BookingStatus.COMPLETED) {
			throw new InvalidBookingStateException("Değerlendirme sadece COMPLETED randevuda verilebilir");
		}

		booking.setCandidateToExpertRating(rating);
		booking.setCandidateToExpertComment(comment != null && !comment.isBlank() ? comment.trim() : null);
		Booking saved = this.bookingRepository.save(booking);

		// Uzman ortalamasını user-service/shop tarafına yansıtmak için event publish et.
		Double avg = this.bookingRepository.avgExpertRating(saved.getExpertId());
		long totalRated = this.bookingRepository.countRated(saved.getExpertId());
		BigDecimal avgBd = avg == null ? BigDecimal.ZERO : BigDecimal.valueOf(avg).setScale(2, RoundingMode.HALF_UP);
		this.eventPublisher.publishEvent(new ExpertRatingUpdatedDomainEvent(saved.getExpertId(), avgBd, totalRated));

		return BookingResponse.from(saved);
	}

	@Transactional
	public BookingResponse deleteCandidateComment(UUID bookingId, UUID candidateId) {
		Booking booking = this.bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BookingNotFoundException("Booking bulunamadı: " + bookingId));

		if (!booking.getCandidateId().equals(candidateId)) {
			throw new BookingNotFoundException("Booking bulunamadı: " + bookingId);
		}
		if (booking.getStatus() != BookingStatus.COMPLETED) {
			throw new InvalidBookingStateException("Yorum sadece COMPLETED randevuda silinebilir");
		}

		booking.setCandidateToExpertComment(null);
		return BookingResponse.from(this.bookingRepository.save(booking));
	}
}
