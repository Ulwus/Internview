package io.internview.booking_service.repository;

import java.util.UUID;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import io.internview.booking_service.domain.Booking;
import io.internview.booking_service.domain.BookingStatus;

public interface BookingRepository extends JpaRepository<Booking, UUID> {

	Optional<Booking> findBySlotId(UUID slotId);

	boolean existsBySlotIdAndStatusIn(UUID slotId, java.util.Collection<BookingStatus> statuses);

	Page<Booking> findByCandidateIdOrderByScheduledStartDesc(UUID candidateId, Pageable pageable);

	Page<Booking> findByExpertIdOrderByScheduledStartDesc(UUID expertId, Pageable pageable);

	@Query("""
		select b from Booking b
		where b.status = io.internview.booking_service.domain.BookingStatus.CONFIRMED
		  and b.scheduledEnd < :now
	""")
	java.util.List<Booking> findConfirmedEndedBefore(@Param("now") java.time.Instant now);

	@Query("select avg(b.candidateToExpertRating) from Booking b where b.expertId = :expertId and b.candidateToExpertRating is not null")
	Double avgExpertRating(@Param("expertId") UUID expertId);

	@Query("select count(b) from Booking b where b.expertId = :expertId and b.candidateToExpertRating is not null")
	long countRated(@Param("expertId") UUID expertId);

	@Query("select count(b) from Booking b where b.expertId = :expertId and b.status = io.internview.booking_service.domain.BookingStatus.COMPLETED")
	long countCompleted(@Param("expertId") UUID expertId);

	@Query("select count(b) from Booking b where b.expertId = :expertId and b.status = io.internview.booking_service.domain.BookingStatus.CANCELLED")
	long countCancelled(@Param("expertId") UUID expertId);

	@Query("""
		select b from Booking b
		where b.expertId = :expertId
		  and b.status = io.internview.booking_service.domain.BookingStatus.COMPLETED
		  and (b.candidateToExpertComment is not null or b.candidateToExpertRating is not null)
		order by b.scheduledEnd desc
	""")
	Page<Booking> findCompletedReviews(@Param("expertId") UUID expertId, Pageable pageable);
}
