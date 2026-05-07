package io.internview.interview_service.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "interview_sessions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class InterviewSession {

	@Id
	@Column(name = "id", nullable = false, updatable = false)
	private UUID id;

	@Column(name = "booking_id", nullable = false, unique = true, updatable = false)
	private UUID bookingId;

	@Column(name = "candidate_id", nullable = false, updatable = false)
	private UUID candidateId;

	@Column(name = "expert_id", nullable = false, updatable = false)
	private UUID expertId;

	@Column(name = "scheduled_time", nullable = false)
	private Instant scheduledTime;

	@Column(name = "status", nullable = false, length = 32)
	private String status;

	@Column(name = "expert_joined_at")
	private Instant expertJoinedAt;

	@Column(name = "created_at", nullable = false, updatable = false)
	private Instant createdAt;

	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;

	@PrePersist
	void onCreate() {
		if (this.id == null) {
			this.id = UUID.randomUUID();
		}
		Instant now = Instant.now();
		if (this.createdAt == null) {
			this.createdAt = now;
		}
		this.updatedAt = now;
		if (this.status == null || this.status.isBlank()) {
			this.status = "SCHEDULED";
		}
	}

	@PreUpdate
	void onUpdate() {
		this.updatedAt = Instant.now();
	}
}

