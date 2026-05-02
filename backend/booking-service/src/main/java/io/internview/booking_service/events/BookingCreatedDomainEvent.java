package io.internview.booking_service.events;

import java.time.Instant;
import java.util.UUID;

public record BookingCreatedDomainEvent(
	UUID bookingId,
	UUID candidateId,
	UUID expertId,
	UUID slotId,
	Instant scheduledTime,
	String status
) {}

