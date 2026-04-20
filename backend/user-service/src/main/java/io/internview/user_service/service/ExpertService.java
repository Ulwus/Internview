package io.internview.user_service.service;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.user_service.domain.ExpertProfile;
import io.internview.user_service.domain.Industry;
import io.internview.user_service.domain.Skill;
import io.internview.user_service.domain.User;
import io.internview.user_service.domain.UserRole;
import io.internview.user_service.error.ExpertProfileNotFoundException;
import io.internview.user_service.error.InvalidRoleException;
import io.internview.user_service.error.UserNotFoundException;
import io.internview.user_service.repository.ExpertProfileRepository;
import io.internview.user_service.repository.ExpertProfileSpecifications;
import io.internview.user_service.repository.IndustryRepository;
import io.internview.user_service.repository.SkillRepository;
import io.internview.user_service.repository.UserRepository;
import io.internview.user_service.web.dto.ExpertDetailResponse;
import io.internview.user_service.web.dto.ExpertSummaryResponse;
import io.internview.user_service.web.dto.UpdateExpertProfileRequest;
import io.internview.user_service.web.mapper.ExpertProfileMapper;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class ExpertService {

	private final ExpertProfileRepository expertProfileRepository;
	private final UserRepository userRepository;
	private final IndustryRepository industryRepository;
	private final SkillRepository skillRepository;

	@Transactional(readOnly = true)
	public Page<ExpertSummaryResponse> search(ExpertFilter filter, Pageable pageable) {
		Specification<ExpertProfile> spec = Specification.allOf(
			ExpertProfileSpecifications.industrySlug(filter.getIndustrySlug()),
			ExpertProfileSpecifications.hasAnySkillSlug(filter.getSkillSlugs()),
			ExpertProfileSpecifications.minRating(filter.getMinRating()),
			ExpertProfileSpecifications.maxHourlyRate(filter.getMaxHourlyRate()),
			ExpertProfileSpecifications.isAvailable(filter.getIsAvailable()),
			ExpertProfileSpecifications.search(filter.getSearch())
		);
		return expertProfileRepository.findAll(spec, pageable).map(ExpertProfileMapper::toSummary);
	}

	@Transactional(readOnly = true)
	public ExpertDetailResponse getById(UUID id) {
		ExpertProfile profile = expertProfileRepository.findById(id)
			.orElseThrow(() -> new ExpertProfileNotFoundException("Uzman profili bulunamadı: " + id));
		return ExpertProfileMapper.toDetail(profile);
	}

	@Transactional(readOnly = true)
	public ExpertDetailResponse getByUserId(UUID userId) {
		ExpertProfile profile = expertProfileRepository.findByUserId(userId)
			.orElseThrow(() -> new ExpertProfileNotFoundException("Kullanıcıya ait uzman profili yok: " + userId));
		return ExpertProfileMapper.toDetail(profile);
	}

	@Transactional
	public ExpertDetailResponse updateOwnProfile(UUID userId, UpdateExpertProfileRequest request) {
		User user = userRepository.findById(userId)
			.orElseThrow(() -> new UserNotFoundException("Kullanıcı bulunamadı: " + userId));

		if (user.getRole() != UserRole.EXPERT) {
			throw new InvalidRoleException("Sadece EXPERT rolündeki kullanıcılar uzman profilini güncelleyebilir");
		}

		ExpertProfile profile = expertProfileRepository.findByUserId(userId)
			.orElseGet(() -> createDefaultProfile(user));

		applyUpdates(profile, request);

		return ExpertProfileMapper.toDetail(expertProfileRepository.save(profile));
	}

	private ExpertProfile createDefaultProfile(User user) {
		return ExpertProfile.builder()
			.id(UUID.randomUUID())
			.user(user)
			.yearsOfExperience(0)
			.currency("USD")
			.averageRating(java.math.BigDecimal.ZERO)
			.totalSessions(0)
			.isVerified(false)
			.isAvailable(true)
			.skills(new HashSet<>())
			.build();
	}

	private void applyUpdates(ExpertProfile profile, UpdateExpertProfileRequest request) {
		if (request.getHeadline() != null) {
			profile.setHeadline(request.getHeadline());
		}
		if (request.getBio() != null) {
			profile.setBio(request.getBio());
		}
		if (request.getCompany() != null) {
			profile.setCompany(request.getCompany());
		}
		if (request.getYearsOfExperience() != null) {
			profile.setYearsOfExperience(request.getYearsOfExperience());
		}
		if (request.getHourlyRate() != null) {
			profile.setHourlyRate(request.getHourlyRate());
		}
		if (request.getCurrency() != null) {
			profile.setCurrency(request.getCurrency());
		}
		if (request.getIsAvailable() != null) {
			profile.setIsAvailable(request.getIsAvailable());
		}
		if (request.getIndustrySlug() != null) {
			if (request.getIndustrySlug().isBlank()) {
				profile.setIndustry(null);
			} else {
				Industry industry = industryRepository.findBySlug(request.getIndustrySlug())
					.orElseThrow(() -> new IllegalArgumentException(
						"Sektör slug bulunamadı: " + request.getIndustrySlug()));
				profile.setIndustry(industry);
			}
		}
		if (request.getSkillSlugs() != null) {
			Set<String> normalized = new HashSet<>();
			for (String slug : request.getSkillSlugs()) {
				if (slug != null && !slug.isBlank()) {
					normalized.add(slug);
				}
			}
			if (normalized.isEmpty()) {
				profile.getSkills().clear();
			} else {
				List<Skill> found = skillRepository.findBySlugIn(normalized);
				if (found.size() != normalized.size()) {
					Set<String> foundSlugs = new HashSet<>();
					for (Skill s : found) {
						foundSlugs.add(s.getSlug());
					}
					normalized.removeAll(foundSlugs);
					throw new IllegalArgumentException("Yetenek slug'ları bulunamadı: " + normalized);
				}
				profile.setSkills(new HashSet<>(found));
			}
		}
	}
}
