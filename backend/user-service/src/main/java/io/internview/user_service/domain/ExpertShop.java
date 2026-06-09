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
@Table(name = "expert_shops")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExpertShop {

	@Id
	@Column(nullable = false, updatable = false)
	private UUID id;

	@Column(name = "expert_user_id", nullable = false, unique = true, updatable = false)
	private UUID expertUserId;

	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "industry_id")
	private Industry industry;

	@Column(columnDefinition = "TEXT")
	private String description;

	@Column(name = "years_of_experience", nullable = false)
	private Integer yearsOfExperience;

	@Column(name = "hourly_rate", precision = 10, scale = 2)
	private BigDecimal hourlyRate;

	@Column(nullable = false, length = 3)
	private String currency;

	@Column(name = "is_published", nullable = false)
	private Boolean isPublished;

	@ManyToMany(fetch = FetchType.LAZY)
	@JoinTable(
		name = "expert_shop_skills",
		joinColumns = @JoinColumn(name = "expert_shop_id"),
		inverseJoinColumns = @JoinColumn(name = "skill_id")
	)
	@Builder.Default
	private Set<Skill> skills = new HashSet<>();

	// Filtreleme için expert_profiles tablosuna join (user_id üzerinden)
	@OneToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "expert_user_id", referencedColumnName = "user_id", insertable = false, updatable = false)
	private ExpertProfile expertProfile;

	@CreationTimestamp
	@Column(name = "created_at", nullable = false, updatable = false)
	private Instant createdAt;

	@UpdateTimestamp
	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;
}

