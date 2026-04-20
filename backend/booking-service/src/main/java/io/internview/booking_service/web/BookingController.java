package io.internview.booking_service.web;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import io.internview.booking_service.service.BookingService;
import io.internview.booking_service.web.dto.BookingResponse;
import io.internview.booking_service.web.dto.CreateBookingRequest;
import io.internview.booking_service.web.dto.PageResponse;
import io.internview.booking_service.web.dto.UpdateBookingStatusRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/bookings")
@RequiredArgsConstructor
public class BookingController {

	private final BookingService bookingService;

	@PostMapping
	@PreAuthorize("hasRole('CANDIDATE')")
	public ResponseEntity<ApiResponse<BookingResponse>> create(
		@AuthenticationPrincipal Jwt jwt,
		@Valid @RequestBody CreateBookingRequest request) {
		UUID candidateId = UUID.fromString(jwt.getSubject());
		BookingResponse created = this.bookingService.createBooking(candidateId, request);
		return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(created));
	}

	@GetMapping("/{id}")
	@PreAuthorize("isAuthenticated()")
	public ApiResponse<BookingResponse> getById(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
		UUID viewerId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.bookingService.getById(id, viewerId));
	}

	@GetMapping("/me/candidate")
	@PreAuthorize("hasRole('CANDIDATE')")
	public ApiResponse<PageResponse<BookingResponse>> listMineAsCandidate(
		@AuthenticationPrincipal Jwt jwt,
		@RequestParam(defaultValue = "0") int page,
		@RequestParam(defaultValue = "20") int size) {
		UUID candidateId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.bookingService.listForCandidate(candidateId, page, size));
	}

	@GetMapping("/me/expert")
	@PreAuthorize("hasRole('EXPERT')")
	public ApiResponse<PageResponse<BookingResponse>> listMineAsExpert(
		@AuthenticationPrincipal Jwt jwt,
		@RequestParam(defaultValue = "0") int page,
		@RequestParam(defaultValue = "20") int size) {
		UUID expertId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.bookingService.listForExpert(expertId, page, size));
	}

	@PatchMapping("/{id}/status")
	@PreAuthorize("isAuthenticated()")
	public ApiResponse<BookingResponse> updateStatus(
		@AuthenticationPrincipal Jwt jwt,
		@PathVariable UUID id,
		@Valid @RequestBody UpdateBookingStatusRequest request) {
		UUID actorId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.bookingService.updateStatus(id, actorId, request.getStatus()));
	}
}
