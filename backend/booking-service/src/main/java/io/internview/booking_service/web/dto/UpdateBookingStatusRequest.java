package io.internview.booking_service.web.dto;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import io.internview.booking_service.domain.BookingStatus;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@Builder
@RequiredArgsConstructor(onConstructor_ = @JsonCreator(mode = JsonCreator.Mode.PROPERTIES))
public class UpdateBookingStatusRequest {

	@NotNull(message = "status zorunlu")
	@JsonProperty("status")
	private final BookingStatus status;
}
