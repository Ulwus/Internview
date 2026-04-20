package io.internview.booking_service.web;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.internview.booking_service.service.AvailabilityService;
import io.internview.booking_service.web.dto.CreateSlotRequest;
import io.internview.booking_service.web.dto.SlotResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
public class AvailabilityController {

	private final AvailabilityService availabilityService;

	@GetMapping("/availability/{expertId}")
	public ApiResponse<List<SlotResponse>> listOpen(@PathVariable UUID expertId) {
		return ApiResponse.ok(this.availabilityService.listOpenSlots(expertId));
	}

	@GetMapping("/experts/me/availability")
	@PreAuthorize("hasRole('EXPERT')")
	public ApiResponse<List<SlotResponse>> listMine(@AuthenticationPrincipal Jwt jwt) {
		UUID expertId = UUID.fromString(jwt.getSubject());
		return ApiResponse.ok(this.availabilityService.listAllSlotsForExpert(expertId));
	}

	@PostMapping("/experts/me/availability")
	@PreAuthorize("hasRole('EXPERT')")
	public ResponseEntity<ApiResponse<SlotResponse>> create(
		@AuthenticationPrincipal Jwt jwt,
		@Valid @RequestBody CreateSlotRequest request) {
		UUID expertId = UUID.fromString(jwt.getSubject());
		SlotResponse created = this.availabilityService.createSlot(expertId, request);
		return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(created));
	}

	@DeleteMapping("/experts/me/availability/{slotId}")
	@PreAuthorize("hasRole('EXPERT')")
	public ResponseEntity<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID slotId) {
		UUID expertId = UUID.fromString(jwt.getSubject());
		this.availabilityService.deleteSlot(expertId, slotId);
		return ResponseEntity.noContent().build();
	}
}
