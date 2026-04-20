package io.internview.booking_service.lock;

import java.util.UUID;
import java.util.function.Supplier;

/**
 * Slot bazlı kısa süreli distributed lock. Aynı slot'a paralel gelen rezervasyon
 * isteklerinden yalnızca biri kritik bölgeye girebilsin diye kullanılır.
 */
public interface BookingLockService {

	/**
	 * Verilen slot için lock'u aldıktan sonra {@code action} çalıştırır. Lock
	 * alınamazsa {@link SlotLockedException} fırlatır. Her koşulda lock serbest
	 * bırakılır.
	 */
	<T> T runWithSlotLock(UUID slotId, Supplier<T> action);

	class SlotLockedException extends RuntimeException {
		public SlotLockedException(UUID slotId) {
			super("Slot " + slotId + " için eş zamanlı rezervasyon işlemi var");
		}
	}
}
