package io.internview.booking_service.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.booking_service.domain.Booking;
import io.internview.booking_service.repository.BookingRepository;
import io.internview.booking_service.web.dto.ExpertReviewResponse;
import io.internview.booking_service.web.dto.ExpertStatsResponse;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class ExpertInsightsService {

	private static final int MAX_PAGE_SIZE = 100;

	private final BookingRepository bookingRepository;

	@Transactional(readOnly = true)
	public ExpertStatsResponse getStats(UUID expertUserId) {
		Double avg = bookingRepository.avgExpertRating(expertUserId);
		long rated = bookingRepository.countRated(expertUserId);
		long completed = bookingRepository.countCompleted(expertUserId);
		long cancelled = bookingRepository.countCancelled(expertUserId);

		BigDecimal avgBd = avg == null ? null : BigDecimal.valueOf(avg).setScale(2, RoundingMode.HALF_UP);

		return ExpertStatsResponse.builder()
			.expertUserId(expertUserId)
			.averageRating(avgBd)
			.totalRated(rated)
			.completedCount(completed)
			.cancelledCount(cancelled)
			.build();
	}

	@Transactional(readOnly = true)
	public Page<ExpertReviewResponse> getReviews(UUID expertUserId, int page, int size) {
		Pageable pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), MAX_PAGE_SIZE));
		return bookingRepository.findCompletedReviews(expertUserId, pageable).map(ExpertInsightsService::toReview);
	}

	private static ExpertReviewResponse toReview(Booking b) {
		return ExpertReviewResponse.builder()
			.bookingId(b.getId())
			.rating(b.getCandidateToExpertRating())
			.comment(b.getCandidateToExpertComment())
			.scheduledEnd(b.getScheduledEnd())
			.build();
	}
}

