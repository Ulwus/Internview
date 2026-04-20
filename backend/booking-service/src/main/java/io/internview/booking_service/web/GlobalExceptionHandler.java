package io.internview.booking_service.web;

import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import io.internview.booking_service.error.BookingNotFoundException;
import io.internview.booking_service.error.InvalidBookingStateException;
import io.internview.booking_service.error.InvalidSlotException;
import io.internview.booking_service.error.SlotAlreadyBookedException;
import io.internview.booking_service.error.SlotNotFoundException;
import io.internview.booking_service.lock.BookingLockService.SlotLockedException;

@RestControllerAdvice
public class GlobalExceptionHandler {

	@ExceptionHandler(MethodArgumentNotValidException.class)
	public ResponseEntity<ApiErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
		String msg = ex.getBindingResult()
			.getFieldErrors()
			.stream()
			.map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
			.collect(Collectors.joining("; "));
		return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiErrorResponse.of("VALIDATION_ERROR", msg));
	}

	@ExceptionHandler(SlotNotFoundException.class)
	public ResponseEntity<ApiErrorResponse> handleSlotNotFound(SlotNotFoundException ex) {
		return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiErrorResponse.of("SLOT_NOT_FOUND", ex.getMessage()));
	}

	@ExceptionHandler(BookingNotFoundException.class)
	public ResponseEntity<ApiErrorResponse> handleBookingNotFound(BookingNotFoundException ex) {
		return ResponseEntity.status(HttpStatus.NOT_FOUND)
			.body(ApiErrorResponse.of("BOOKING_NOT_FOUND", ex.getMessage()));
	}

	@ExceptionHandler(SlotAlreadyBookedException.class)
	public ResponseEntity<ApiErrorResponse> handleSlotAlreadyBooked(SlotAlreadyBookedException ex) {
		return ResponseEntity.status(HttpStatus.CONFLICT)
			.body(ApiErrorResponse.of("SLOT_ALREADY_BOOKED", ex.getMessage()));
	}

	@ExceptionHandler(SlotLockedException.class)
	public ResponseEntity<ApiErrorResponse> handleSlotLocked(SlotLockedException ex) {
		return ResponseEntity.status(HttpStatus.CONFLICT)
			.body(ApiErrorResponse.of("SLOT_LOCKED", ex.getMessage()));
	}

	@ExceptionHandler(InvalidBookingStateException.class)
	public ResponseEntity<ApiErrorResponse> handleInvalidState(InvalidBookingStateException ex) {
		return ResponseEntity.status(HttpStatus.CONFLICT)
			.body(ApiErrorResponse.of("INVALID_BOOKING_STATE", ex.getMessage()));
	}

	@ExceptionHandler(InvalidSlotException.class)
	public ResponseEntity<ApiErrorResponse> handleInvalidSlot(InvalidSlotException ex) {
		return ResponseEntity.status(HttpStatus.BAD_REQUEST)
			.body(ApiErrorResponse.of("INVALID_SLOT", ex.getMessage()));
	}

	@ExceptionHandler(AccessDeniedException.class)
	public ResponseEntity<ApiErrorResponse> handleForbidden(AccessDeniedException ex) {
		return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiErrorResponse.of("ACCESS_DENIED", ex.getMessage()));
	}

	@ExceptionHandler(IllegalArgumentException.class)
	public ResponseEntity<ApiErrorResponse> handleBadRequest(IllegalArgumentException ex) {
		return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiErrorResponse.of("BAD_REQUEST", ex.getMessage()));
	}
}
