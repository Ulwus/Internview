package io.internview.booking_service.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import io.internview.booking_service.domain.AvailabilitySlot;
import io.internview.booking_service.error.InvalidSlotException;
import io.internview.booking_service.error.SlotAlreadyBookedException;
import io.internview.booking_service.error.SlotNotFoundException;
import io.internview.booking_service.repository.AvailabilitySlotRepository;
import io.internview.booking_service.web.dto.CreateSlotRequest;
import io.internview.booking_service.web.dto.SlotResponse;

@ExtendWith(MockitoExtension.class)
class AvailabilityServiceTest {

	@Mock
	private AvailabilitySlotRepository slotRepository;

	@InjectMocks
	private AvailabilityService availabilityService;

	private UUID expertId;

	@BeforeEach
	void setUp() {
		expertId = UUID.randomUUID();
	}

	@Test
	void createSlot_withValidRange_persistsAndReturns() {
		Instant start = Instant.now().plus(1, ChronoUnit.HOURS);
		Instant end = start.plus(30, ChronoUnit.MINUTES);
		CreateSlotRequest request = CreateSlotRequest.builder().startTime(start).endTime(end).build();

		when(slotRepository.save(any(AvailabilitySlot.class))).thenAnswer(i -> i.getArgument(0));

		SlotResponse response = availabilityService.createSlot(expertId, request);

		assertThat(response.getExpertId()).isEqualTo(expertId);
		assertThat(response.getStartTime()).isEqualTo(start);
		assertThat(response.getEndTime()).isEqualTo(end);
		assertThat(response.isBooked()).isFalse();
	}

	@Test
	void createSlot_whenEndBeforeStart_throws() {
		Instant start = Instant.now().plus(2, ChronoUnit.HOURS);
		Instant end = start.minus(10, ChronoUnit.MINUTES);
		CreateSlotRequest request = CreateSlotRequest.builder().startTime(start).endTime(end).build();

		assertThatThrownBy(() -> availabilityService.createSlot(expertId, request))
			.isInstanceOf(InvalidSlotException.class);

		verify(slotRepository, never()).save(any());
	}

	@Test
	void createSlot_whenStartInPast_throws() {
		Instant start = Instant.now().minus(10, ChronoUnit.MINUTES);
		Instant end = Instant.now().plus(10, ChronoUnit.MINUTES);
		CreateSlotRequest request = CreateSlotRequest.builder().startTime(start).endTime(end).build();

		assertThatThrownBy(() -> availabilityService.createSlot(expertId, request))
			.isInstanceOf(InvalidSlotException.class);
	}

	@Test
	void listOpenSlots_returnsMappedResponses() {
		AvailabilitySlot slot = AvailabilitySlot.builder()
			.id(UUID.randomUUID())
			.expertId(expertId)
			.startTime(Instant.now().plus(1, ChronoUnit.HOURS))
			.endTime(Instant.now().plus(2, ChronoUnit.HOURS))
			.booked(false)
			.build();
		when(slotRepository
			.findByExpertIdAndBookedFalseAndStartTimeGreaterThanEqualOrderByStartTimeAsc(any(), any()))
			.thenReturn(List.of(slot));

		List<SlotResponse> result = availabilityService.listOpenSlots(expertId);

		assertThat(result).hasSize(1);
		assertThat(result.get(0).getId()).isEqualTo(slot.getId());
	}

	@Test
	void deleteSlot_whenSlotBelongsToOther_throws() {
		UUID slotId = UUID.randomUUID();
		AvailabilitySlot slot = AvailabilitySlot.builder()
			.id(slotId)
			.expertId(UUID.randomUUID())
			.startTime(Instant.now().plus(1, ChronoUnit.HOURS))
			.endTime(Instant.now().plus(2, ChronoUnit.HOURS))
			.booked(false)
			.build();
		when(slotRepository.findById(slotId)).thenReturn(Optional.of(slot));

		assertThatThrownBy(() -> availabilityService.deleteSlot(expertId, slotId))
			.isInstanceOf(InvalidSlotException.class);
	}

	@Test
	void deleteSlot_whenAlreadyBooked_throws() {
		UUID slotId = UUID.randomUUID();
		AvailabilitySlot slot = AvailabilitySlot.builder()
			.id(slotId)
			.expertId(expertId)
			.startTime(Instant.now().plus(1, ChronoUnit.HOURS))
			.endTime(Instant.now().plus(2, ChronoUnit.HOURS))
			.booked(true)
			.build();
		when(slotRepository.findById(slotId)).thenReturn(Optional.of(slot));

		assertThatThrownBy(() -> availabilityService.deleteSlot(expertId, slotId))
			.isInstanceOf(SlotAlreadyBookedException.class);
	}

	@Test
	void deleteSlot_whenMissing_throws() {
		UUID slotId = UUID.randomUUID();
		when(slotRepository.findById(slotId)).thenReturn(Optional.empty());

		assertThatThrownBy(() -> availabilityService.deleteSlot(expertId, slotId))
			.isInstanceOf(SlotNotFoundException.class);
	}
}
