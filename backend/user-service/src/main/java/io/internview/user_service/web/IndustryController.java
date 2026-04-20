package io.internview.user_service.web;

import java.util.List;

import org.springframework.data.domain.Sort;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.internview.user_service.repository.IndustryRepository;
import io.internview.user_service.web.dto.IndustryResponse;
import io.internview.user_service.web.mapper.ExpertProfileMapper;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/industries")
@RequiredArgsConstructor
public class IndustryController {

	private final IndustryRepository industryRepository;

	@GetMapping
	public ApiResponse<List<IndustryResponse>> list() {
		List<IndustryResponse> industries = this.industryRepository.findAll(Sort.by("name")).stream()
			.map(ExpertProfileMapper::toIndustryResponse)
			.toList();
		return ApiResponse.ok(industries);
	}
}
