package io.internview.user_service.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "expert_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExpertProfile {

	@Id
	@Column(nullable = false, updatable = false)
	private UUID id;

	@OneToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "user_id", nullable = false, unique = true)
	private User user;

	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "industry_id")
	private Industry industry;

	@Column(length = 160)
	private String headline;

	@Column(columnDefinition = "TEXT")
	private String bio;

	@Column(length = 160)
	private String company;

	@Column(name = "years_of_experience", nullable = false)
	private Integer yearsOfExperience;

	@Column(name = "hourly_rate", precision = 10, scale = 2)
	private BigDecimal hourlyRate;

	@Column(nullable = false, length = 3)
	private String currency;

	@Column(name = "average_rating", nullable = false, precision = 3, scale = 2)
	private BigDecimal averageRating;

	@Column(name = "total_sessions", nullable = false)
	private Integer totalSessions;

	@Column(name = "is_verified", nullable = false)
	private Boolean isVerified;

	@Column(name = "is_available", nullable = false)
	private Boolean isAvailable;

	@ManyToMany(fetch = FetchType.LAZY)
	@JoinTable(
		name = "expert_profile_skills",
		joinColumns = @JoinColumn(name = "expert_profile_id"),
		inverseJoinColumns = @JoinColumn(name = "skill_id")
	)
	@Builder.Default
	private Set<Skill> skills = new HashSet<>();

	@CreationTimestamp
	@Column(name = "created_at", nullable = false, updatable = false)
	private Instant createdAt;

	@UpdateTimestamp
	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;
}
