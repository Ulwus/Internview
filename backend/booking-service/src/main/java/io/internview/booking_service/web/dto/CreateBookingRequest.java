package io.internview.booking_service.web.dto;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.NotNull;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@Builder
@RequiredArgsConstructor(onConstructor_ = @JsonCreator(mode = JsonCreator.Mode.PROPERTIES))
public class CreateBookingRequest {

	@NotNull(message = "expertId zorunlu")
	@JsonProperty("expertId")
	private final UUID expertId;

	@NotNull(message = "slotId zorunlu")
	@JsonProperty("slotId")
	private final UUID slotId;
}
