package io.internview.user_service.web;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import io.internview.user_service.service.ExpertFilter;
import io.internview.user_service.service.ExpertService;
import io.internview.user_service.web.dto.ExpertDetailResponse;
import io.internview.user_service.web.dto.ExpertSummaryResponse;

@SpringBootTest
@AutoConfigureMockMvc
class ExpertControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private ExpertService expertService;

	@Test
	void search_returnsPage_withoutAuth() throws Exception {
		ExpertSummaryResponse summary = ExpertSummaryResponse.builder()
			.id(UUID.randomUUID())
			.userId(UUID.randomUUID())
			.firstName("Eda")
			.lastName("Demir")
			.yearsOfExperience(5)
			.hourlyRate(BigDecimal.valueOf(100))
			.currency("USD")
			.averageRating(BigDecimal.valueOf(4.5))
			.totalSessions(10)
			.isVerified(true)
			.isAvailable(true)
			.skills(List.of())
			.build();
		Page<ExpertSummaryResponse> page = new PageImpl<>(List.of(summary), Pageable.ofSize(20), 1);
		when(expertService.search(any(ExpertFilter.class), any(Pageable.class))).thenReturn(page);

		mockMvc.perform(get("/experts"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.success").value(true))
			.andExpect(jsonPath("$.data.items[0].firstName").value("Eda"))
			.andExpect(jsonPath("$.data.totalElements").value(1));
	}

	@Test
	void me_requiresExpertRole() throws Exception {
		mockMvc.perform(get("/experts/me")
			.with(jwt().jwt(j -> j.subject(UUID.randomUUID().toString()).claim("role", "CANDIDATE"))))
			.andExpect(status().isForbidden());
	}

	@Test
	void me_withExpertRole_returnsProfile() throws Exception {
		UUID userId = UUID.randomUUID();
		ExpertDetailResponse detail = ExpertDetailResponse.builder()
			.id(UUID.randomUUID())
			.userId(userId)
			.email("expert@example.com")
			.firstName("Eda")
			.lastName("Demir")
			.yearsOfExperience(5)
			.currency("USD")
			.averageRating(BigDecimal.valueOf(4.5))
			.totalSessions(10)
			.isVerified(true)
			.isAvailable(true)
			.skills(List.of())
			.build();
		when(expertService.getByUserId(userId)).thenReturn(detail);

		mockMvc.perform(get("/experts/me")
			.with(jwt()
				.jwt(j -> j.subject(userId.toString()).claim("role", "EXPERT"))
				.authorities(new SimpleGrantedAuthority("ROLE_EXPERT"))))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.email").value("expert@example.com"));
	}
}
