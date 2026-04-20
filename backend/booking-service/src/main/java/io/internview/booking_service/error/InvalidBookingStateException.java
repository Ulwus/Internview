package io.internview.booking_service.error;

public class InvalidBookingStateException extends RuntimeException {

	public InvalidBookingStateException(String message) {
		super(message);
	}
}
