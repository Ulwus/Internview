from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class AnalyzeRequest(BaseModel):
    session_id: UUID
    booking_id: UUID | None = None
    candidate_id: UUID | None = None
    expert_id: UUID | None = None
    duration_seconds: float | None = Field(default=None, ge=0)
    recorded_video_url: str


class AnalyzeResponse(BaseModel):
    session_id: UUID
    transcript: str
    analysis: dict[str, Any]


class InterviewCompletedPayload(BaseModel):
    session_id: UUID
    booking_id: UUID
    candidate_id: UUID
    expert_id: UUID
    duration_seconds: float | None = None
    recorded_video_url: str


class InterviewCompletedEvent(BaseModel):
    event_type: str
    event_id: str
    timestamp: str | float
    payload: InterviewCompletedPayload

    @field_validator("timestamp", mode="before")
    @classmethod
    def _coerce_timestamp(cls, v):
        if isinstance(v, (int, float)):
            from datetime import datetime, timezone
            return datetime.fromtimestamp(v, tz=timezone.utc).isoformat()
        return v


class RecordingSegmentPayload(BaseModel):
    session_id: UUID
    segment_index: int
    start_second: float
    end_second: float
    duration_seconds: float | None = None
    recorded_video_url: str
    s3_key: str


class RecordingSegmentUploadedEvent(BaseModel):
    event_type: str
    event_id: str
    timestamp: str
    payload: RecordingSegmentPayload
