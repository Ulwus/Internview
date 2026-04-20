package io.internview.booking_service.domain;

/**
 * Booking lifecycle. Geçerli geçişler:
 *   PENDING   -> CONFIRMED | CANCELLED
 *   CONFIRMED -> COMPLETED | CANCELLED
 *   COMPLETED -> (terminal)
 *   CANCELLED -> (terminal)
 */
public enum BookingStatus {
	PENDING,
	CONFIRMED,
	COMPLETED,
	CANCELLED;

	public boolean canTransitionTo(BookingStatus next) {
		if (next == null || next == this) {
			return false;
		}
		return switch (this) {
			case PENDING   -> next == CONFIRMED || next == CANCELLED;
			case CONFIRMED -> next == COMPLETED || next == CANCELLED;
			case COMPLETED, CANCELLED -> false;
		};
	}
}
