package io.internview.user_service.web.dto;

import java.util.UUID;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class SkillResponse {

	UUID id;
	String name;
	String slug;
}
