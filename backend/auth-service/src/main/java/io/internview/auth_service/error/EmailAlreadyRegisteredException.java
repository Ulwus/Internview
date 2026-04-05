package io.internview.auth_service.error;

public class EmailAlreadyRegisteredException extends RuntimeException {

	public EmailAlreadyRegisteredException(String message) {
		super(message);
	}
}
