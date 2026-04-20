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
import io.internview.booking_service.domain.BookingStatus;
import io.internview.booking_service.service.BookingService;
import io.internview.booking_service.web.dto.BookingResponse;

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestBookingLockConfig.class)
class BookingControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private BookingService bookingService;

	@Test
	void createBooking_withoutAuth_returnsUnauthorized() throws Exception {
		String body = """
			{"expertId":"%s","slotId":"%s"}
			""".formatted(UUID.randomUUID().toString(), UUID.randomUUID().toString());
		mockMvc.perform(post("/bookings")
			.with(csrf())
			.contentType(MediaType.APPLICATION_JSON)
			.content(body))
			.andExpect(status().isUnauthorized());
	}

	@Test
	void createBooking_withExpertRole_returnsForbidden() throws Exception {
		UUID userId = UUID.randomUUID();
		String body = """
			{"expertId":"%s","slotId":"%s"}
			""".formatted(UUID.randomUUID().toString(), UUID.randomUUID().toString());
		mockMvc.perform(post("/bookings")
			.with(csrf())
			.with(jwt()
				.jwt(j -> j.subject(userId.toString()).claim("role", "EXPERT"))
				.authorities(new SimpleGrantedAuthority("ROLE_EXPERT")))
			.contentType(MediaType.APPLICATION_JSON)
			.content(body))
			.andExpect(status().isForbidden());
	}

	@Test
	void createBooking_withCandidateRole_returnsCreated() throws Exception {
		UUID candidateId = UUID.randomUUID();
		UUID expertId = UUID.randomUUID();
		UUID slotId = UUID.randomUUID();

		BookingResponse response = BookingResponse.builder()
			.id(UUID.randomUUID())
			.candidateId(candidateId)
			.expertId(expertId)
			.slotId(slotId)
			.status(BookingStatus.CONFIRMED)
			.scheduledStart(Instant.now().plus(1, ChronoUnit.HOURS))
			.scheduledEnd(Instant.now().plus(2, ChronoUnit.HOURS))
			.build();
		when(bookingService.createBooking(eq(candidateId), any())).thenReturn(response);

		String body = """
			{"expertId":"%s","slotId":"%s"}
			""".formatted(expertId.toString(), slotId.toString());

		mockMvc.perform(post("/bookings")
			.with(csrf())
			.with(jwt()
				.jwt(j -> j.subject(candidateId.toString()).claim("role", "CANDIDATE"))
				.authorities(new SimpleGrantedAuthority("ROLE_CANDIDATE")))
			.contentType(MediaType.APPLICATION_JSON)
			.content(body))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.data.status").value("CONFIRMED"))
			.andExpect(jsonPath("$.data.candidateId").value(candidateId.toString()));
	}

	@Test
	void createBooking_withInvalidBody_returns400() throws Exception {
		UUID candidateId = UUID.randomUUID();
		// eksik alan: sadece slotId
		String body = """
			{"slotId":"%s"}
			""".formatted(UUID.randomUUID().toString());

		mockMvc.perform(post("/bookings")
			.with(csrf())
			.with(jwt()
				.jwt(j -> j.subject(candidateId.toString()).claim("role", "CANDIDATE"))
				.authorities(new SimpleGrantedAuthority("ROLE_CANDIDATE")))
			.contentType(MediaType.APPLICATION_JSON)
			.content(body))
			.andExpect(status().isBadRequest());
	}

	@Test
	void getById_whenAuthenticated_returnsBooking() throws Exception {
		UUID candidateId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();

		BookingResponse response = BookingResponse.builder()
			.id(bookingId)
			.candidateId(candidateId)
			.expertId(UUID.randomUUID())
			.slotId(UUID.randomUUID())
			.status(BookingStatus.CONFIRMED)
			.scheduledStart(Instant.now().plus(1, ChronoUnit.HOURS))
			.scheduledEnd(Instant.now().plus(2, ChronoUnit.HOURS))
			.build();
		when(bookingService.getById(bookingId, candidateId)).thenReturn(response);

		mockMvc.perform(get("/bookings/" + bookingId)
			.with(jwt()
				.jwt(j -> j.subject(candidateId.toString()).claim("role", "CANDIDATE"))
				.authorities(new SimpleGrantedAuthority("ROLE_CANDIDATE"))))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.id").value(bookingId.toString()));
	}

	@Test
	void getById_withoutAuth_returnsUnauthorized() throws Exception {
		mockMvc.perform(get("/bookings/" + UUID.randomUUID()))
			.andExpect(status().isUnauthorized());
	}
}
