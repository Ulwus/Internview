package io.internview.user_service.repository;

import java.math.BigDecimal;
import java.util.Set;
import java.util.UUID;

import org.springframework.data.jpa.domain.Specification;

import io.internview.user_service.domain.ExpertProfile;
import io.internview.user_service.domain.ExpertShop;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.JoinType;

public final class ExpertShopSpecifications {

	private ExpertShopSpecifications() {}

	public static Specification<ExpertShop> publishedOnly(Boolean onlyPublished) {
		if (onlyPublished == null || !onlyPublished) return null;
		return (root, query, cb) -> cb.isTrue(root.get("isPublished"));
	}

	public static Specification<ExpertShop> expertUserIdIn(Set<UUID> userIds) {
		if (userIds == null || userIds.isEmpty()) return null;
		return (root, query, cb) -> root.get("expertUserId").in(userIds);
	}

	public static Specification<ExpertShop> industrySlug(String slug) {
		if (slug == null || slug.isBlank()) return null;
		return (root, query, cb) -> cb.equal(root.join("industry", JoinType.LEFT).get("slug"), slug);
	}

	public static Specification<ExpertShop> hasAnySkillSlug(Set<String> slugs) {
		if (slugs == null || slugs.isEmpty()) return null;
		return (root, query, cb) -> {
			query.distinct(true);
			Join<Object, Object> skills = root.join("skills", JoinType.LEFT);
			return skills.get("slug").in(slugs);
		};
	}

	public static Specification<ExpertShop> minPrice(BigDecimal min) {
		if (min == null) return null;
		return (root, query, cb) -> cb.greaterThanOrEqualTo(root.get("hourlyRate"), min);
	}

	public static Specification<ExpertShop> maxPrice(BigDecimal max) {
		if (max == null) return null;
		return (root, query, cb) -> cb.lessThanOrEqualTo(root.get("hourlyRate"), max);
	}

	public static Specification<ExpertShop> minRating(BigDecimal minRating) {
		if (minRating == null) return null;
		return (root, query, cb) -> {
			Join<ExpertShop, ExpertProfile> p = root.join("expertProfile", JoinType.LEFT);
			return cb.greaterThanOrEqualTo(p.get("averageRating"), minRating);
		};
	}

	public static Specification<ExpertShop> isAvailable(Boolean isAvailable) {
		if (isAvailable == null) return null;
		return (root, query, cb) -> {
			Join<ExpertShop, ExpertProfile> p = root.join("expertProfile", JoinType.LEFT);
			return cb.equal(p.get("isAvailable"), isAvailable);
		};
	}
}

