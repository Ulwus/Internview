package io.internview.user_service.repository;

import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import io.internview.user_service.domain.Skill;

@Repository
public interface SkillRepository extends JpaRepository<Skill, UUID> {

	Optional<Skill> findBySlug(String slug);

	List<Skill> findBySlugIn(Set<String> slugs);
}
