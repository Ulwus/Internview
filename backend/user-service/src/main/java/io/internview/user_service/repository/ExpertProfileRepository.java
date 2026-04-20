package io.internview.user_service.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import io.internview.user_service.domain.ExpertProfile;

@Repository
public interface ExpertProfileRepository
		extends JpaRepository<ExpertProfile, UUID>, JpaSpecificationExecutor<ExpertProfile> {

	Optional<ExpertProfile> findByUserId(UUID userId);
}
