package io.internview.user_service.error;

public class ExpertProfileNotFoundException extends RuntimeException {

	public ExpertProfileNotFoundException(String message) {
		super(message);
	}
}
