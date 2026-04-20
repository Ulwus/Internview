package io.internview.booking_service.web;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import io.internview.booking_service.TestBookingLockConfig;
import io.internview.booking_service.service.AvailabilityService;
import io.internview.booking_service.web.dto.SlotResponse;

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestBookingLockConfig.class)
class AvailabilityControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private AvailabilityService availabilityService;

	@Test
	void listOpen_isPublic_returnsOk() throws Exception {
		UUID expertId = UUID.randomUUID();
		SlotResponse slot = SlotResponse.builder()
			.id(UUID.randomUUID())
			.expertId(expertId)
			.startTime(Instant.now().plus(1, ChronoUnit.HOURS))
			.endTime(Instant.now().plus(2, ChronoUnit.HOURS))
			.booked(false)
			.build();
		when(availabilityService.listOpenSlots(expertId)).thenReturn(List.of(slot));

		mockMvc.perform(get("/availability/" + expertId))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data[0].expertId").value(expertId.toString()));
	}

	@Test
	void createSlot_withoutAuth_returnsUnauthorized() throws Exception {
		String body = """
			{"startTime":"%s","endTime":"%s"}
			""".formatted(
				Instant.now().plus(1, ChronoUnit.HOURS).toString(),
				Instant.now().plus(2, ChronoUnit.HOURS).toString());
		mockMvc.perform(post("/experts/me/availability")
			.with(csrf())
			.contentType(MediaType.APPLICATION_JSON)
			.content(body))
			.andExpect(status().isUnauthorized());
	}

	@Test
	void createSlot_withCandidateRole_returnsForbidden() throws Exception {
		UUID userId = UUID.randomUUID();
		String body = """
			{"startTime":"%s","endTime":"%s"}
			""".formatted(
				Instant.now().plus(1, ChronoUnit.HOURS).toString(),
				Instant.now().plus(2, ChronoUnit.HOURS).toString());

		mockMvc.perform(post("/experts/me/availability")
			.with(csrf())
			.with(jwt()
				.jwt(j -> j.subject(userId.toString()).claim("role", "CANDIDATE"))
				.authorities(new SimpleGrantedAuthority("ROLE_CANDIDATE")))
			.contentType(MediaType.APPLICATION_JSON)
			.content(body))
			.andExpect(status().isForbidden());
	}

	@Test
	void createSlot_withExpertRole_returnsCreated() throws Exception {
		UUID expertId = UUID.randomUUID();
		Instant start = Instant.now().plus(1, ChronoUnit.HOURS);
		Instant end = Instant.now().plus(2, ChronoUnit.HOURS);

		SlotResponse created = SlotResponse.builder()
			.id(UUID.randomUUID())
			.expertId(expertId)
			.startTime(start)
			.endTime(end)
			.booked(false)
			.build();
		when(availabilityService.createSlot(eq(expertId), any())).thenReturn(created);

		String body = """
			{"startTime":"%s","endTime":"%s"}
			""".formatted(start.toString(), end.toString());

		mockMvc.perform(post("/experts/me/availability")
			.with(csrf())
			.with(jwt()
				.jwt(j -> j.subject(expertId.toString()).claim("role", "EXPERT"))
				.authorities(new SimpleGrantedAuthority("ROLE_EXPERT")))
			.contentType(MediaType.APPLICATION_JSON)
			.content(body))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.data.expertId").value(expertId.toString()));
	}
}
