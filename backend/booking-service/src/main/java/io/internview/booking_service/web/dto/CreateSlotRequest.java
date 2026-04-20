package io.internview.booking_service.web.dto;

import java.time.Instant;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.NotNull;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@Builder
@RequiredArgsConstructor(onConstructor_ = @JsonCreator(mode = JsonCreator.Mode.PROPERTIES))
public class CreateSlotRequest {

	@NotNull(message = "startTime zorunlu")
	@JsonProperty("startTime")
	private final Instant startTime;

	@NotNull(message = "endTime zorunlu")
	@JsonProperty("endTime")
	private final Instant endTime;
}
