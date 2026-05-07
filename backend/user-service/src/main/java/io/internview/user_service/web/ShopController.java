package io.internview.user_service.web;

import java.math.BigDecimal;
import java.util.Set;
import java.util.UUID;

import org.springframework.data.domain.Page;
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

import io.internview.user_service.service.ShopService;
import io.internview.user_service.web.dto.PageResponse;
import io.internview.user_service.web.dto.ShopSummaryResponse;
import io.internview.user_service.web.dto.UpsertShopRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/shops")
@RequiredArgsConstructor
public class ShopController {

	private final ShopService shopService;

	@GetMapping
	@PreAuthorize("isAuthenticated()")
	public ApiResponse<PageResponse<ShopSummaryResponse>> list(
		@RequestParam(required = false) String industry,
		@RequestParam(required = false, name = "skill") Set<String> skillSlugs,
		@RequestParam(required = false, name = "min_rating") BigDecimal minRating,
		@RequestParam(required = false, name = "min_price") BigDecimal minPrice,
		@RequestParam(required = false, name = "max_price") BigDecimal maxPrice,
		@RequestParam(required = false, name = "is_available") Boolean isAvailable,
		@RequestParam(required = false, name = "published_only") Boolean publishedOnly,
		@RequestParam(defaultValue = "0") int page,
		@RequestParam(defaultValue = "20") int size
	) {
		Page<ShopSummaryResponse> result = shopService.list(
			industry,
			skillSlugs,
			minRating,
			minPrice,
			maxPrice,
			isAvailable,
			publishedOnly,
			page,
			size
		);
		return ApiResponse.ok(PageResponse.from(result));
	}

	@GetMapping("/{id}")
	@PreAuthorize("isAuthenticated()")
	public ApiResponse<ShopSummaryResponse> getById(@PathVariable UUID id) {
		return ApiResponse.ok(this.shopService.getById(id));
	}

	@GetMapping("/me")
	@PreAuthorize("hasRole('EXPERT')")
	public ApiResponse<ShopSummaryResponse> getMine(@AuthenticationPrincipal Jwt jwt) {
		UUID expertUserId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.shopService.getMine(expertUserId));
	}

	@PutMapping("/me")
	@PreAuthorize("hasRole('EXPERT')")
	public ApiResponse<ShopSummaryResponse> upsertMine(
		@AuthenticationPrincipal Jwt jwt,
		@Valid @RequestBody UpsertShopRequest request
	) {
		UUID expertUserId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.shopService.upsertMine(expertUserId, request));
	}
}

