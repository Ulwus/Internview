package io.internview.interview_service.domain;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "interview_analysis")
@Getter
@Setter
public class InterviewAnalysis {

	@Id
	@Column(name = "id", nullable = false, updatable = false)
	private UUID id;

	@OneToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "session_id", nullable = false, unique = true)
	private InterviewSession session;

	@Column(name = "transcript", nullable = false, columnDefinition = "TEXT")
	private String transcript;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(name = "analysis_result", nullable = false)
	private Map<String, Object> analysisResult;

	@Column(name = "created_at", nullable = false, updatable = false)
	private Instant createdAt;
}
