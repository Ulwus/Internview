package io.internview.user_service.web;

import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import io.internview.user_service.domain.UserRole;
import io.internview.user_service.service.UserService;
import io.internview.user_service.web.dto.UserProfileResponse;

@SpringBootTest
@AutoConfigureMockMvc
class UserControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private UserService userService;

	private UserProfileResponse sampleProfile(UUID userId) {
		return UserProfileResponse.builder()
			.id(userId)
			.email("u@example.com")
			.firstName("Ali")
			.lastName("Yılmaz")
			.role(UserRole.CANDIDATE)
			.createdAt(Instant.now())
			.updatedAt(Instant.now())
			.build();
	}

	@Test
	void getProfile_withoutAuth_returnsUnauthorized() throws Exception {
		mockMvc.perform(get("/users/profile"))
			.andExpect(status().isUnauthorized());
	}

	@Test
	void getProfile_withAuth_returnsProfile() throws Exception {
		UUID userId = UUID.randomUUID();
		when(userService.getById(userId)).thenReturn(sampleProfile(userId));

		mockMvc.perform(get("/users/profile")
			.with(jwt().jwt(j -> j.subject(userId.toString()).claim("role", "CANDIDATE"))))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.email").value("u@example.com"));
	}

	@Test
	void updateProfile_withInvalidBody_returns400() throws Exception {
		UUID userId = UUID.randomUUID();
		String body = "{\"firstName\":\"" + "x".repeat(200) + "\"}";
		mockMvc.perform(put("/users/profile")
			.with(csrf())
			.with(jwt().jwt(j -> j.subject(userId.toString()).claim("role", "CANDIDATE")))
			.contentType(MediaType.APPLICATION_JSON)
			.content(body))
			.andExpect(status().isBadRequest());
	}
}
