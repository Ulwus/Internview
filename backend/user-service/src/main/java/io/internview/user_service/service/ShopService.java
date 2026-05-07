package io.internview.user_service.service;

import java.math.BigDecimal;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Stream;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.internview.user_service.domain.ExpertShop;
import io.internview.user_service.domain.Industry;
import io.internview.user_service.domain.Skill;
import io.internview.user_service.domain.User;
import io.internview.user_service.domain.UserRole;
import io.internview.user_service.error.InvalidRoleException;
import io.internview.user_service.error.UserNotFoundException;
import io.internview.user_service.repository.ExpertShopRepository;
import io.internview.user_service.repository.ExpertShopSpecifications;
import io.internview.user_service.repository.IndustryRepository;
import io.internview.user_service.repository.SkillRepository;
import io.internview.user_service.repository.UserRepository;
import io.internview.user_service.web.dto.UpsertShopRequest;
import io.internview.user_service.web.dto.ShopSummaryResponse;
import io.internview.user_service.web.mapper.ShopMapper;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class ShopService {

	private static final int MAX_PAGE_SIZE = 100;

	private final ExpertShopRepository shopRepository;
	private final UserRepository userRepository;
	private final IndustryRepository industryRepository;
	private final SkillRepository skillRepository;

	@Transactional(readOnly = true)
	public Page<ShopSummaryResponse> list(
		String industrySlug,
		Set<String> skillSlugs,
		BigDecimal minRating,
		BigDecimal minPrice,
		BigDecimal maxPrice,
		Boolean isAvailable,
		Boolean publishedOnly,
		int page,
		int size
	) {
		List<Specification<ExpertShop>> specs = Stream.<Specification<ExpertShop>>of(
			ExpertShopSpecifications.publishedOnly(publishedOnly),
			ExpertShopSpecifications.industrySlug(industrySlug),
			ExpertShopSpecifications.hasAnySkillSlug(skillSlugs),
			ExpertShopSpecifications.minRating(minRating),
			ExpertShopSpecifications.minPrice(minPrice),
			ExpertShopSpecifications.maxPrice(maxPrice),
			ExpertShopSpecifications.isAvailable(isAvailable)
		).filter(Objects::nonNull).toList();

		Specification<ExpertShop> spec = specs.stream().reduce(Specification::and).orElse(null);
		Pageable pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), MAX_PAGE_SIZE));
		return shopRepository.findAll(spec, pageable).map(ShopMapper::toSummary);
	}

	@Transactional(readOnly = true)
	public ShopSummaryResponse getById(UUID id) {
		ExpertShop shop = shopRepository.findById(id)
			.orElseThrow(() -> new IllegalArgumentException("Dükkan bulunamadı: " + id));
		return ShopMapper.toSummary(shop);
	}

	@Transactional(readOnly = true)
	public ShopSummaryResponse getMine(UUID expertUserId) {
		ExpertShop shop = shopRepository.findByExpertUserId(expertUserId).orElse(null);
		if (shop == null) return null;
		return ShopMapper.toSummary(shop);
	}

	@Transactional
	public ShopSummaryResponse upsertMine(UUID expertUserId, UpsertShopRequest request) {
		User user = userRepository.findById(expertUserId)
			.orElseThrow(() -> new UserNotFoundException("Kullanıcı bulunamadı: " + expertUserId));
		if (user.getRole() != UserRole.EXPERT) {
			throw new InvalidRoleException("Sadece EXPERT rolündeki kullanıcılar dükkan açabilir");
		}

		ExpertShop shop = shopRepository.findByExpertUserId(expertUserId).orElse(null);
		if (shop == null) {
			shop = ExpertShop.builder()
				.id(UUID.randomUUID())
				.expertUserId(expertUserId)
				.yearsOfExperience(0)
				.currency("USD")
				.isPublished(false)
				.skills(new HashSet<>())
				.build();
		}

		applyUpdates(shop, request);
		return ShopMapper.toSummary(shopRepository.save(shop));
	}

	private void applyUpdates(ExpertShop shop, UpsertShopRequest request) {
		if (request.getDescription() != null) {
			shop.setDescription(request.getDescription());
		}
		if (request.getYearsOfExperience() != null) {
			shop.setYearsOfExperience(Math.max(request.getYearsOfExperience(), 0));
		}
		if (request.getHourlyRate() != null) {
			shop.setHourlyRate(request.getHourlyRate());
		}
		if (request.getCurrency() != null && !request.getCurrency().isBlank()) {
			shop.setCurrency(request.getCurrency().trim());
		}
		if (request.getIsPublished() != null) {
			shop.setIsPublished(request.getIsPublished());
		}
		if (request.getIndustrySlug() != null) {
			if (request.getIndustrySlug().isBlank()) {
				shop.setIndustry(null);
			} else {
				Industry industry = industryRepository.findBySlug(request.getIndustrySlug())
					.orElseThrow(() -> new IllegalArgumentException("Sektör slug bulunamadı: " + request.getIndustrySlug()));
				shop.setIndustry(industry);
			}
		}
		if (request.getSkillSlugs() != null) {
			Set<String> normalized = new HashSet<>();
			for (String slug : request.getSkillSlugs()) {
				if (slug != null && !slug.isBlank()) normalized.add(slug.trim());
			}
			if (normalized.isEmpty()) {
				shop.getSkills().clear();
			} else {
				List<Skill> found = skillRepository.findBySlugIn(normalized);
				if (found.size() != normalized.size()) {
					Set<String> foundSlugs = new HashSet<>();
					for (Skill s : found) foundSlugs.add(s.getSlug());
					normalized.removeAll(foundSlugs);
					throw new IllegalArgumentException("Yetenek slug'ları bulunamadı: " + normalized);
				}
				shop.setSkills(new HashSet<>(found));
			}
		}
	}
}

