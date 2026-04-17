package io.internview.user_service.web;

import java.util.List;

import org.springframework.data.domain.Sort;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.internview.user_service.repository.SkillRepository;
import io.internview.user_service.web.dto.SkillResponse;
import io.internview.user_service.web.mapper.ExpertProfileMapper;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/skills")
@RequiredArgsConstructor
public class SkillController {

	private final SkillRepository skillRepository;

	@GetMapping
	public ApiResponse<List<SkillResponse>> list() {
		List<SkillResponse> skills = this.skillRepository.findAll(Sort.by("name")).stream()
			.map(ExpertProfileMapper::toSkillResponse)
			.toList();
		return ApiResponse.ok(skills);
	}
}
