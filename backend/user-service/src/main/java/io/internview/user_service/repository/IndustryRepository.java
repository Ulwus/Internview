package io.internview.user_service.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import io.internview.user_service.domain.Industry;

@Repository
public interface IndustryRepository extends JpaRepository<Industry, UUID> {

	Optional<Industry> findBySlug(String slug);
}
