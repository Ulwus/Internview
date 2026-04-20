package io.internview.user_service.web.mapper;

import java.util.Comparator;
import java.util.List;
import java.util.Set;

import io.internview.user_service.domain.ExpertProfile;
import io.internview.user_service.domain.Industry;
import io.internview.user_service.domain.Skill;
import io.internview.user_service.web.dto.ExpertDetailResponse;
import io.internview.user_service.web.dto.ExpertSummaryResponse;
import io.internview.user_service.web.dto.IndustryResponse;
import io.internview.user_service.web.dto.SkillResponse;

public final class ExpertProfileMapper {

	private ExpertProfileMapper() {
	}

	public static ExpertSummaryResponse toSummary(ExpertProfile profile) {
		return ExpertSummaryResponse.builder()
			.id(profile.getId())
			.userId(profile.getUser().getId())
			.firstName(profile.getUser().getFirstName())
			.lastName(profile.getUser().getLastName())
			.avatarUrl(profile.getUser().getAvatarUrl())
			.headline(profile.getHeadline())
			.company(profile.getCompany())
			.industry(toIndustryResponse(profile.getIndustry()))
			.skills(toSkillResponses(profile.getSkills()))
			.yearsOfExperience(profile.getYearsOfExperience())
			.hourlyRate(profile.getHourlyRate())
			.currency(profile.getCurrency())
			.averageRating(profile.getAverageRating())
			.totalSessions(profile.getTotalSessions())
			.isVerified(profile.getIsVerified())
			.isAvailable(profile.getIsAvailable())
			.build();
	}

	public static ExpertDetailResponse toDetail(ExpertProfile profile) {
		return ExpertDetailResponse.builder()
			.id(profile.getId())
			.userId(profile.getUser().getId())
			.email(profile.getUser().getEmail())
			.firstName(profile.getUser().getFirstName())
			.lastName(profile.getUser().getLastName())
			.avatarUrl(profile.getUser().getAvatarUrl())
			.headline(profile.getHeadline())
			.bio(profile.getBio())
			.company(profile.getCompany())
			.industry(toIndustryResponse(profile.getIndustry()))
			.skills(toSkillResponses(profile.getSkills()))
			.yearsOfExperience(profile.getYearsOfExperience())
			.hourlyRate(profile.getHourlyRate())
			.currency(profile.getCurrency())
			.averageRating(profile.getAverageRating())
			.totalSessions(profile.getTotalSessions())
			.isVerified(profile.getIsVerified())
			.isAvailable(profile.getIsAvailable())
			.createdAt(profile.getCreatedAt())
			.updatedAt(profile.getUpdatedAt())
			.build();
	}

	public static IndustryResponse toIndustryResponse(Industry industry) {
		if (industry == null) {
			return null;
		}
		return IndustryResponse.builder()
			.id(industry.getId())
			.name(industry.getName())
			.slug(industry.getSlug())
			.build();
	}

	public static SkillResponse toSkillResponse(Skill skill) {
		return SkillResponse.builder().id(skill.getId()).name(skill.getName()).slug(skill.getSlug()).build();
	}

	public static List<SkillResponse> toSkillResponses(Set<Skill> skills) {
		if (skills == null || skills.isEmpty()) {
			return List.of();
		}
		return skills.stream()
			.sorted(Comparator.comparing(Skill::getName))
			.map(ExpertProfileMapper::toSkillResponse)
			.toList();
	}
}
