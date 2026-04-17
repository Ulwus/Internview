package io.internview.user_service.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import io.internview.user_service.domain.ExpertProfile;
import io.internview.user_service.domain.Industry;
import io.internview.user_service.domain.Skill;
import io.internview.user_service.domain.User;
import io.internview.user_service.domain.UserRole;
import io.internview.user_service.error.ExpertProfileNotFoundException;
import io.internview.user_service.error.InvalidRoleException;
import io.internview.user_service.repository.ExpertProfileRepository;
import io.internview.user_service.repository.IndustryRepository;
import io.internview.user_service.repository.SkillRepository;
import io.internview.user_service.repository.UserRepository;
import io.internview.user_service.web.dto.ExpertDetailResponse;
import io.internview.user_service.web.dto.UpdateExpertProfileRequest;

@ExtendWith(MockitoExtension.class)
class ExpertServiceTest {

	@Mock
	private ExpertProfileRepository expertProfileRepository;

	@Mock
	private UserRepository userRepository;

	@Mock
	private IndustryRepository industryRepository;

	@Mock
	private SkillRepository skillRepository;

	@InjectMocks
	private ExpertService expertService;

	private User expertUser;
	private UUID userId;
	private UUID profileId;
	private ExpertProfile profile;

	@BeforeEach
	void setUp() {
		userId = UUID.randomUUID();
		profileId = UUID.randomUUID();
		expertUser = User.builder()
			.id(userId)
			.email("expert@example.com")
			.passwordHash("hash")
			.firstName("Eda")
			.lastName("Demir")
			.role(UserRole.EXPERT)
			.build();

		profile = ExpertProfile.builder()
			.id(profileId)
			.user(expertUser)
			.yearsOfExperience(5)
			.currency("USD")
			.averageRating(BigDecimal.valueOf(4.5))
			.totalSessions(10)
			.isVerified(true)
			.isAvailable(true)
			.build();
	}

	@Test
	void getById_returnsDetail() {
		when(expertProfileRepository.findById(profileId)).thenReturn(Optional.of(profile));

		ExpertDetailResponse response = expertService.getById(profileId);

		assertThat(response.getId()).isEqualTo(profileId);
		assertThat(response.getEmail()).isEqualTo("expert@example.com");
	}

	@Test
	void getById_whenMissing_throws() {
		when(expertProfileRepository.findById(any())).thenReturn(Optional.empty());
		assertThatThrownBy(() -> expertService.getById(UUID.randomUUID()))
			.isInstanceOf(ExpertProfileNotFoundException.class);
	}

	@Test
	void updateOwnProfile_whenUserNotExpert_throws() {
		User candidate = User.builder()
			.id(userId)
			.email("c@example.com")
			.passwordHash("hash")
			.firstName("C")
			.lastName("D")
			.role(UserRole.CANDIDATE)
			.build();
		when(userRepository.findById(userId)).thenReturn(Optional.of(candidate));

		assertThatThrownBy(() -> expertService.updateOwnProfile(userId,
			UpdateExpertProfileRequest.builder().headline("X").build()))
			.isInstanceOf(InvalidRoleException.class);
	}

	@Test
	void updateOwnProfile_updatesFieldsAndIndustry() {
		when(userRepository.findById(userId)).thenReturn(Optional.of(expertUser));
		when(expertProfileRepository.findByUserId(userId)).thenReturn(Optional.of(profile));

		Industry industry = Industry.builder()
			.id(UUID.randomUUID())
			.name("Teknoloji")
			.slug("teknoloji")
			.build();
		when(industryRepository.findBySlug("teknoloji")).thenReturn(Optional.of(industry));

		Skill java = Skill.builder().id(UUID.randomUUID()).name("Java").slug("java").build();
		when(skillRepository.findBySlugIn(Set.of("java"))).thenReturn(List.of(java));

		when(expertProfileRepository.save(any(ExpertProfile.class))).thenAnswer(inv -> inv.getArgument(0));

		UpdateExpertProfileRequest request = UpdateExpertProfileRequest.builder()
			.headline("Senior Dev")
			.bio("Uzman bio")
			.company("Acme")
			.industrySlug("teknoloji")
			.skillSlugs(Set.of("java"))
			.yearsOfExperience(7)
			.hourlyRate(BigDecimal.valueOf(100))
			.currency("USD")
			.isAvailable(true)
			.build();

		ExpertDetailResponse response = expertService.updateOwnProfile(userId, request);

		assertThat(response.getHeadline()).isEqualTo("Senior Dev");
		assertThat(response.getCompany()).isEqualTo("Acme");
		assertThat(response.getYearsOfExperience()).isEqualTo(7);
		assertThat(response.getIndustry().getSlug()).isEqualTo("teknoloji");
		assertThat(response.getSkills()).extracting("slug").containsExactly("java");
	}

	@Test
	void updateOwnProfile_whenSkillMissing_throws() {
		when(userRepository.findById(userId)).thenReturn(Optional.of(expertUser));
		when(expertProfileRepository.findByUserId(userId)).thenReturn(Optional.of(profile));
		when(skillRepository.findBySlugIn(Set.of("java", "python"))).thenReturn(List.of(
			Skill.builder().id(UUID.randomUUID()).name("Java").slug("java").build()
		));

		UpdateExpertProfileRequest request = UpdateExpertProfileRequest.builder()
			.skillSlugs(Set.of("java", "python"))
			.build();

		assertThatThrownBy(() -> expertService.updateOwnProfile(userId, request))
			.isInstanceOf(IllegalArgumentException.class);
	}
}
