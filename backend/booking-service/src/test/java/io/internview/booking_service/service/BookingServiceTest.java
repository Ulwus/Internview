package io.internview.booking_service.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

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

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class BookingServiceTest {

	@Mock
	private BookingRepository bookingRepository;

	@Mock
	private AvailabilitySlotRepository slotRepository;

	@Mock
	private BookingLockService lockService;

	@InjectMocks
	private BookingService bookingService;

	private UUID candidateId;
	private UUID expertId;
	private UUID slotId;
	private AvailabilitySlot slot;

	@BeforeEach
	void setUp() {
		candidateId = UUID.randomUUID();
		expertId = UUID.randomUUID();
		slotId = UUID.randomUUID();
		slot = AvailabilitySlot.builder()
			.id(slotId)
			.expertId(expertId)
			.startTime(Instant.now().plus(1, ChronoUnit.HOURS))
			.endTime(Instant.now().plus(2, ChronoUnit.HOURS))
			.booked(false)
			.build();

		// Lock'u passthrough yap - lock alındı say, action'ı çağır
		when(lockService.runWithSlotLock(any(), any())).thenAnswer(inv -> {
			Supplier<?> supplier = inv.getArgument(1);
			return supplier.get();
		});
	}

	@Test
	void createBooking_happyPath_marksSlotBookedAndReturns() {
		when(slotRepository.findById(slotId)).thenReturn(Optional.of(slot));
		when(bookingRepository.existsBySlotIdAndStatusIn(eq(slotId), anyCollection())).thenReturn(false);
		when(bookingRepository.save(any(Booking.class))).thenAnswer(inv -> {
			Booking b = inv.getArgument(0);
			if (b.getId() == null) b.setId(UUID.randomUUID());
			return b;
		});

		CreateBookingRequest request = CreateBookingRequest.builder()
			.expertId(expertId)
			.slotId(slotId)
			.build();

		BookingResponse response = bookingService.createBooking(candidateId, request);

		assertThat(response.getCandidateId()).isEqualTo(candidateId);
		assertThat(response.getExpertId()).isEqualTo(expertId);
		assertThat(response.getSlotId()).isEqualTo(slotId);
		assertThat(response.getStatus()).isEqualTo(BookingStatus.CONFIRMED);
		assertThat(slot.isBooked()).isTrue();
		verify(slotRepository).save(slot);
	}

	@Test
	void createBooking_whenSlotMissing_throws() {
		when(slotRepository.findById(slotId)).thenReturn(Optional.empty());

		CreateBookingRequest request = CreateBookingRequest.builder()
			.expertId(expertId)
			.slotId(slotId)
			.build();

		assertThatThrownBy(() -> bookingService.createBooking(candidateId, request))
			.isInstanceOf(SlotNotFoundException.class);

		verify(bookingRepository, never()).save(any());
	}

	@Test
	void createBooking_whenSlotBelongsToDifferentExpert_throws() {
		when(slotRepository.findById(slotId)).thenReturn(Optional.of(slot));

		CreateBookingRequest request = CreateBookingRequest.builder()
			.expertId(UUID.randomUUID()) // farklı uzman
			.slotId(slotId)
			.build();

		assertThatThrownBy(() -> bookingService.createBooking(candidateId, request))
			.isInstanceOf(InvalidSlotException.class);

		verify(bookingRepository, never()).save(any());
	}

	@Test
	void createBooking_whenSlotAlreadyBooked_throws() {
		slot.setBooked(true);
		when(slotRepository.findById(slotId)).thenReturn(Optional.of(slot));

		CreateBookingRequest request = CreateBookingRequest.builder()
			.expertId(expertId)
			.slotId(slotId)
			.build();

		assertThatThrownBy(() -> bookingService.createBooking(candidateId, request))
			.isInstanceOf(SlotAlreadyBookedException.class);

		verify(bookingRepository, never()).save(any());
	}

	@Test
	void createBooking_whenActiveBookingExists_throwsDoubleBooking() {
		when(slotRepository.findById(slotId)).thenReturn(Optional.of(slot));
		when(bookingRepository.existsBySlotIdAndStatusIn(eq(slotId), anyCollection())).thenReturn(true);

		CreateBookingRequest request = CreateBookingRequest.builder()
			.expertId(expertId)
			.slotId(slotId)
			.build();

		assertThatThrownBy(() -> bookingService.createBooking(candidateId, request))
			.isInstanceOf(SlotAlreadyBookedException.class);

		verify(bookingRepository, never()).save(any());
	}

	@Test
	void getById_whenViewerIsOwner_returnsBooking() {
		UUID bookingId = UUID.randomUUID();
		Booking booking = sampleBooking(bookingId, BookingStatus.CONFIRMED);
		when(bookingRepository.findById(bookingId)).thenReturn(Optional.of(booking));

		BookingResponse response = bookingService.getById(bookingId, candidateId);

		assertThat(response.getId()).isEqualTo(bookingId);
	}

	@Test
	void getById_whenViewerIsStranger_throws() {
		UUID bookingId = UUID.randomUUID();
		Booking booking = sampleBooking(bookingId, BookingStatus.CONFIRMED);
		when(bookingRepository.findById(bookingId)).thenReturn(Optional.of(booking));

		assertThatThrownBy(() -> bookingService.getById(bookingId, UUID.randomUUID()))
			.isInstanceOf(BookingNotFoundException.class);
	}

	@Test
	void updateStatus_confirmedToCompleted_ok() {
		UUID bookingId = UUID.randomUUID();
		Booking booking = sampleBooking(bookingId, BookingStatus.CONFIRMED);
		when(bookingRepository.findById(bookingId)).thenReturn(Optional.of(booking));
		when(bookingRepository.save(any())).thenAnswer(i -> i.getArgument(0));

		BookingResponse response = bookingService.updateStatus(bookingId, candidateId, BookingStatus.COMPLETED);

		assertThat(response.getStatus()).isEqualTo(BookingStatus.COMPLETED);
	}

	@Test
	void updateStatus_cancel_freesSlot() {
		UUID bookingId = UUID.randomUUID();
		Booking booking = sampleBooking(bookingId, BookingStatus.CONFIRMED);
		slot.setBooked(true);

		when(bookingRepository.findById(bookingId)).thenReturn(Optional.of(booking));
		when(bookingRepository.save(any())).thenAnswer(i -> i.getArgument(0));
		when(slotRepository.findById(slotId)).thenReturn(Optional.of(slot));

		bookingService.updateStatus(bookingId, candidateId, BookingStatus.CANCELLED);

		assertThat(slot.isBooked()).isFalse();
		verify(slotRepository).save(slot);
	}

	@Test
	void updateStatus_invalidTransition_throws() {
		UUID bookingId = UUID.randomUUID();
		Booking booking = sampleBooking(bookingId, BookingStatus.COMPLETED);
		when(bookingRepository.findById(bookingId)).thenReturn(Optional.of(booking));

		assertThatThrownBy(() -> bookingService.updateStatus(bookingId, candidateId, BookingStatus.CONFIRMED))
			.isInstanceOf(InvalidBookingStateException.class);
	}

	@Test
	void updateStatus_whenActorIsStranger_throws() {
		UUID bookingId = UUID.randomUUID();
		Booking booking = sampleBooking(bookingId, BookingStatus.CONFIRMED);
		when(bookingRepository.findById(bookingId)).thenReturn(Optional.of(booking));

		assertThatThrownBy(() -> bookingService.updateStatus(bookingId, UUID.randomUUID(), BookingStatus.COMPLETED))
			.isInstanceOf(BookingNotFoundException.class);
	}

	private Booking sampleBooking(UUID id, BookingStatus status) {
		return Booking.builder()
			.id(id)
			.candidateId(candidateId)
			.expertId(expertId)
			.slotId(slotId)
			.status(status)
			.scheduledStart(slot.getStartTime())
			.scheduledEnd(slot.getEndTime())
			.build();
	}
}
