package io.internview.booking_service.error;

public class SlotAlreadyBookedException extends RuntimeException {

	public SlotAlreadyBookedException(String message) {
		super(message);
	}
}
