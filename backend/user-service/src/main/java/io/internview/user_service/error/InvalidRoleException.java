package io.internview.user_service.error;

public class InvalidRoleException extends RuntimeException {

	public InvalidRoleException(String message) {
		super(message);
	}
}
