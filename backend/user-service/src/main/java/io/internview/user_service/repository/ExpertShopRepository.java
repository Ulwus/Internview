package io.internview.user_service.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import io.internview.user_service.domain.ExpertShop;

@Repository
public interface ExpertShopRepository extends JpaRepository<ExpertShop, UUID>, JpaSpecificationExecutor<ExpertShop> {
	Optional<ExpertShop> findByExpertUserId(UUID expertUserId);
}

