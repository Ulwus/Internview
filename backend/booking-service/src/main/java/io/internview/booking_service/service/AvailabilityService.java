package io.internview.booking_service.service;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.booking_service.domain.AvailabilitySlot;
import io.internview.booking_service.error.InvalidSlotException;
import io.internview.booking_service.error.SlotAlreadyBookedException;
import io.internview.booking_service.error.SlotNotFoundException;
import io.internview.booking_service.repository.AvailabilitySlotRepository;
import io.internview.booking_service.web.dto.CreateSlotRequest;
import io.internview.booking_service.web.dto.SlotResponse;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class AvailabilityService {

	private final AvailabilitySlotRepository slotRepository;

	@Transactional(readOnly = true)
	public List<SlotResponse> listOpenSlots(UUID expertId) {
		return this.slotRepository
			.findByExpertIdAndBookedFalseAndStartTimeGreaterThanEqualOrderByStartTimeAsc(expertId, Instant.now())
			.stream()
			.map(SlotResponse::from)
			.toList();
	}

	@Transactional(readOnly = true)
	public List<SlotResponse> listAllSlotsForExpert(UUID expertId) {
		return this.slotRepository
			.findByExpertIdAndStartTimeGreaterThanEqualOrderByStartTimeAsc(expertId, Instant.now())
			.stream()
			.map(SlotResponse::from)
			.toList();
	}

	@Transactional
	public SlotResponse createSlot(UUID expertId, CreateSlotRequest request) {
		validateRange(request.getStartTime(), request.getEndTime());
		AvailabilitySlot slot = AvailabilitySlot.builder()
			.expertId(expertId)
			.startTime(request.getStartTime())
			.endTime(request.getEndTime())
			.booked(false)
			.build();
		return SlotResponse.from(this.slotRepository.save(slot));
	}

	@Transactional
	public void deleteSlot(UUID expertId, UUID slotId) {
		AvailabilitySlot slot = this.slotRepository.findById(slotId)
			.orElseThrow(() -> new SlotNotFoundException("Slot bulunamadı: " + slotId));
		if (!slot.getExpertId().equals(expertId)) {
			throw new InvalidSlotException("Bu slot başka bir uzmana ait");
		}
		if (slot.isBooked()) {
			throw new SlotAlreadyBookedException("Rezerve edilmiş slot silinemez");
		}
		this.slotRepository.delete(slot);
	}

	private void validateRange(Instant start, Instant end) {
		if (!end.isAfter(start)) {
			throw new InvalidSlotException("endTime, startTime'dan sonra olmalı");
		}
		if (start.isBefore(Instant.now())) {
			throw new InvalidSlotException("startTime geçmişte olamaz");
		}
	}
}
