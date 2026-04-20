package io.internview.user_service.web;

import java.math.BigDecimal;
import java.util.Set;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import io.internview.user_service.service.ExpertFilter;
import io.internview.user_service.service.ExpertService;
import io.internview.user_service.web.dto.ExpertDetailResponse;
import io.internview.user_service.web.dto.ExpertSummaryResponse;
import io.internview.user_service.web.dto.PageResponse;
import io.internview.user_service.web.dto.UpdateExpertProfileRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/experts")
@RequiredArgsConstructor
public class ExpertController {

	private static final int MAX_PAGE_SIZE = 100;

	private final ExpertService expertService;

	@GetMapping
	public ApiResponse<PageResponse<ExpertSummaryResponse>> search(
		@RequestParam(required = false) String industry,
		@RequestParam(required = false) Set<String> skill,
		@RequestParam(name = "min_rating", required = false) BigDecimal minRating,
		@RequestParam(name = "max_hourly_rate", required = false) BigDecimal maxHourlyRate,
		@RequestParam(name = "is_available", required = false) Boolean isAvailable,
		@RequestParam(required = false) String search,
		@RequestParam(defaultValue = "0") int page,
		@RequestParam(defaultValue = "20") int size,
		@RequestParam(defaultValue = "averageRating,desc") String sort) {

		ExpertFilter filter = ExpertFilter.builder()
			.industrySlug(industry)
			.skillSlugs(skill)
			.minRating(minRating)
			.maxHourlyRate(maxHourlyRate)
			.isAvailable(isAvailable)
			.search(search)
			.build();

		Pageable pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), MAX_PAGE_SIZE), parseSort(sort));
		Page<ExpertSummaryResponse> result = this.expertService.search(filter, pageable);
		return ApiResponse.ok(PageResponse.from(result));
	}

	@GetMapping("/{id}")
	public ApiResponse<ExpertDetailResponse> getById(@PathVariable UUID id) {
		return ApiResponse.ok(this.expertService.getById(id));
	}

	@GetMapping("/me")
	@PreAuthorize("hasRole('EXPERT')")
	public ApiResponse<ExpertDetailResponse> getOwnProfile(@AuthenticationPrincipal Jwt jwt) {
		UUID userId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.expertService.getByUserId(userId));
	}

	@PutMapping("/me")
	@PreAuthorize("hasRole('EXPERT')")
	public ApiResponse<ExpertDetailResponse> updateOwnProfile(
		@AuthenticationPrincipal Jwt jwt,
		@Valid @RequestBody UpdateExpertProfileRequest request) {
		UUID userId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.expertService.updateOwnProfile(userId, request));
	}

	private Sort parseSort(String sortParam) {
		if (sortParam == null || sortParam.isBlank()) {
			return Sort.by(Sort.Direction.DESC, "averageRating");
		}
		String[] parts = sortParam.split(",");
		String property = parts[0].trim();
		Sort.Direction direction = parts.length > 1 && "asc".equalsIgnoreCase(parts[1].trim())
			? Sort.Direction.ASC
			: Sort.Direction.DESC;
		return Sort.by(direction, property);
	}
}
