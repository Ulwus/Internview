package io.internview.booking_service.error;

public class InvalidSlotException extends RuntimeException {

	public InvalidSlotException(String message) {
		super(message);
	}
}
