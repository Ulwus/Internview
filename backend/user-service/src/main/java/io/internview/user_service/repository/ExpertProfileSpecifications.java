package io.internview.user_service.repository;

import java.math.BigDecimal;
import java.util.Set;

import org.springframework.data.jpa.domain.Specification;

import io.internview.user_service.domain.ExpertProfile;
import io.internview.user_service.domain.Industry;
import io.internview.user_service.domain.Skill;
import jakarta.persistence.criteria.Join;

public final class ExpertProfileSpecifications {

	private ExpertProfileSpecifications() {
	}

	public static Specification<ExpertProfile> industrySlug(String slug) {
		if (slug == null || slug.isBlank()) {
			return null;
		}
		return (root, query, cb) -> {
			Join<ExpertProfile, Industry> industry = root.join("industry");
			return cb.equal(cb.lower(industry.get("slug")), slug.toLowerCase());
		};
	}

	public static Specification<ExpertProfile> hasAnySkillSlug(Set<String> slugs) {
		if (slugs == null || slugs.isEmpty()) {
			return null;
		}
		return (root, query, cb) -> {
			if (query != null) {
				query.distinct(true);
			}
			Join<ExpertProfile, Skill> skills = root.join("skills");
			return cb.lower(skills.get("slug")).in(slugs.stream().map(String::toLowerCase).toList());
		};
	}

	public static Specification<ExpertProfile> minRating(BigDecimal minRating) {
		if (minRating == null) {
			return null;
		}
		return (root, query, cb) -> cb.greaterThanOrEqualTo(root.get("averageRating"), minRating);
	}

	public static Specification<ExpertProfile> maxHourlyRate(BigDecimal maxRate) {
		if (maxRate == null) {
			return null;
		}
		return (root, query, cb) -> cb.or(
			cb.isNull(root.get("hourlyRate")),
			cb.lessThanOrEqualTo(root.get("hourlyRate"), maxRate)
		);
	}

	public static Specification<ExpertProfile> isAvailable(Boolean available) {
		if (available == null) {
			return null;
		}
		return (root, query, cb) -> cb.equal(root.get("isAvailable"), available);
	}

	public static Specification<ExpertProfile> search(String term) {
		if (term == null || term.isBlank()) {
			return null;
		}
		String pattern = "%" + term.toLowerCase() + "%";
		return (root, query, cb) -> cb.or(
			cb.like(cb.lower(root.get("headline")), pattern),
			cb.like(cb.lower(root.get("bio")), pattern),
			cb.like(cb.lower(root.get("company")), pattern)
		);
	}
}
