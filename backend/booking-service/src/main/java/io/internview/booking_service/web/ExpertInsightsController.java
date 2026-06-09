package io.internview.booking_service.web;

import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import io.internview.booking_service.service.ExpertInsightsService;
import io.internview.booking_service.web.dto.ExpertReviewResponse;
import io.internview.booking_service.web.dto.ExpertStatsResponse;
import io.internview.booking_service.web.dto.PageResponse;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/experts")
@RequiredArgsConstructor
public class ExpertInsightsController {

	private final ExpertInsightsService expertInsightsService;

	@GetMapping("/{expertUserId}/stats")
	@PreAuthorize("isAuthenticated()")
	public ApiResponse<ExpertStatsResponse> stats(@PathVariable UUID expertUserId) {
		return ApiResponse.ok(expertInsightsService.getStats(expertUserId));
	}

	@GetMapping("/{expertUserId}/reviews")
	@PreAuthorize("isAuthenticated()")
	public ApiResponse<PageResponse<ExpertReviewResponse>> reviews(
		@PathVariable UUID expertUserId,
		@RequestParam(defaultValue = "0") int page,
		@RequestParam(defaultValue = "20") int size
	) {
		Page<ExpertReviewResponse> res = expertInsightsService.getReviews(expertUserId, page, size);
		return ApiResponse.ok(PageResponse.from(res));
	}
}

