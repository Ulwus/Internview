package io.internview.user_service.web.mapper;

import java.util.Set;
import java.util.stream.Collectors;

import io.internview.user_service.domain.ExpertProfile;
import io.internview.user_service.domain.ExpertShop;
import io.internview.user_service.domain.User;
import io.internview.user_service.web.dto.IndustryResponse;
import io.internview.user_service.web.dto.ShopSummaryResponse;
import io.internview.user_service.web.dto.SkillResponse;

public final class ShopMapper {

	private ShopMapper() {}

	public static ShopSummaryResponse toSummary(ExpertShop shop) {
		ExpertProfile p = shop.getExpertProfile();
		User u = p != null ? p.getUser() : null;

		return ShopSummaryResponse.builder()
			.id(shop.getId())
			.expertUserId(shop.getExpertUserId())
			.expertFirstName(u != null ? u.getFirstName() : "")
			.expertLastName(u != null ? u.getLastName() : "")
			.expertAvatarUrl(u != null ? u.getAvatarUrl() : null)
			.industry(shop.getIndustry() != null
				? IndustryResponse.builder()
					.id(shop.getIndustry().getId())
					.name(shop.getIndustry().getName())
					.slug(shop.getIndustry().getSlug())
					.build()
				: null)
			.skills(mapSkills(shop))
			.description(shop.getDescription())
			.yearsOfExperience(shop.getYearsOfExperience())
			.hourlyRate(shop.getHourlyRate())
			.currency(shop.getCurrency())
			.isPublished(shop.getIsPublished())
			.averageRating(p != null ? p.getAverageRating() : null)
			.isAvailable(p != null ? p.getIsAvailable() : null)
			.createdAt(shop.getCreatedAt())
			.updatedAt(shop.getUpdatedAt())
			.build();
	}

	private static Set<SkillResponse> mapSkills(ExpertShop shop) {
		if (shop.getSkills() == null) return Set.of();
		return shop.getSkills().stream()
			.map(s -> SkillResponse.builder().id(s.getId()).name(s.getName()).slug(s.getSlug()).build())
			.collect(Collectors.toSet());
	}
}

