package io.internview.auth_service.web;

import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import io.internview.auth_service.error.EmailAlreadyRegisteredException;
import io.internview.auth_service.error.InvalidCredentialsException;
import io.internview.auth_service.error.InvalidRefreshTokenException;
import io.internview.auth_service.error.UserNotFoundException;

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

	@ExceptionHandler(EmailAlreadyRegisteredException.class)
	public ResponseEntity<ApiErrorResponse> handleConflict(EmailAlreadyRegisteredException ex) {
		return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiErrorResponse.of("EMAIL_ALREADY_REGISTERED", ex.getMessage()));
	}

	@ExceptionHandler(InvalidCredentialsException.class)
	public ResponseEntity<ApiErrorResponse> handleBadLogin(InvalidCredentialsException ex) {
		// 401 + gövde, OAuth2 resource server ile çakışabildiği için iş kuralı hatası olarak 400 dönülür
		return ResponseEntity.status(HttpStatus.BAD_REQUEST)
			.contentType(MediaType.APPLICATION_JSON)
			.body(ApiErrorResponse.of("INVALID_CREDENTIALS", ex.getMessage()));
	}

	@ExceptionHandler(InvalidRefreshTokenException.class)
	public ResponseEntity<ApiErrorResponse> handleBadRefresh(InvalidRefreshTokenException ex) {
		return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
			.contentType(MediaType.APPLICATION_JSON)
			.body(ApiErrorResponse.of("INVALID_REFRESH_TOKEN", ex.getMessage()));
	}

	@ExceptionHandler(UserNotFoundException.class)
	public ResponseEntity<ApiErrorResponse> handleNotFound(UserNotFoundException ex) {
		return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiErrorResponse.of("USER_NOT_FOUND", ex.getMessage()));
	}

	@ExceptionHandler(AccessDeniedException.class)
	public ResponseEntity<ApiErrorResponse> handleForbidden(AccessDeniedException ex) {
		return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiErrorResponse.of("ACCESS_DENIED", ex.getMessage()));
	}
}
