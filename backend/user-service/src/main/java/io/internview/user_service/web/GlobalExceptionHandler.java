package io.internview.user_service.web;

import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import io.internview.user_service.error.ExpertProfileNotFoundException;
import io.internview.user_service.error.InvalidRoleException;
import io.internview.user_service.error.UserNotFoundException;

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

	@ExceptionHandler(UserNotFoundException.class)
	public ResponseEntity<ApiErrorResponse> handleUserNotFound(UserNotFoundException ex) {
		return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiErrorResponse.of("USER_NOT_FOUND", ex.getMessage()));
	}

	@ExceptionHandler(ExpertProfileNotFoundException.class)
	public ResponseEntity<ApiErrorResponse> handleExpertNotFound(ExpertProfileNotFoundException ex) {
		return ResponseEntity.status(HttpStatus.NOT_FOUND)
			.body(ApiErrorResponse.of("EXPERT_PROFILE_NOT_FOUND", ex.getMessage()));
	}

	@ExceptionHandler(InvalidRoleException.class)
	public ResponseEntity<ApiErrorResponse> handleInvalidRole(InvalidRoleException ex) {
		return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiErrorResponse.of("INVALID_ROLE", ex.getMessage()));
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
