package io.internview.booking_service.error;

public class SlotNotFoundException extends RuntimeException {

	public SlotNotFoundException(String message) {
		super(message);
	}
}
