package io.internview.booking_service.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import io.internview.booking_service.domain.Booking;
import io.internview.booking_service.domain.BookingStatus;

public interface BookingRepository extends JpaRepository<Booking, UUID> {

	Optional<Booking> findBySlotId(UUID slotId);

	boolean existsBySlotIdAndStatusIn(UUID slotId, java.util.Collection<BookingStatus> statuses);

	Page<Booking> findByCandidateIdOrderByScheduledStartDesc(UUID candidateId, Pageable pageable);

	Page<Booking> findByExpertIdOrderByScheduledStartDesc(UUID expertId, Pageable pageable);
}
