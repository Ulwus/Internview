package io.internview.booking_service.repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import io.internview.booking_service.domain.AvailabilitySlot;

public interface AvailabilitySlotRepository extends JpaRepository<AvailabilitySlot, UUID> {

	List<AvailabilitySlot> findByExpertIdAndBookedFalseAndStartTimeGreaterThanEqualOrderByStartTimeAsc(
		UUID expertId, Instant from);

	List<AvailabilitySlot> findByExpertIdAndStartTimeGreaterThanEqualOrderByStartTimeAsc(
		UUID expertId, Instant from);
}
