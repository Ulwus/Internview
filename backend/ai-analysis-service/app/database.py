from __future__ import annotations

import json
import logging
from typing import Any
from uuid import UUID

from sqlalchemy import JSON, Text, create_engine, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker
from sqlalchemy.types import DateTime
from sqlalchemy.sql import func

from app.config import settings
from app.llm_evaluator import evaluate_interview
from app.metrics import calculate_overall_score


engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)
logger = logging.getLogger(__name__)


class Base(DeclarativeBase):
    pass


json_type = JSONB().with_variant(JSON(), "sqlite")


class InterviewAnalysis(Base):
    __tablename__ = "interview_analysis"

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    session_id: Mapped[str] = mapped_column(Text, unique=True, nullable=False, index=True)
    transcript: Mapped[str] = mapped_column(Text, nullable=False)
    analysis_result: Mapped[dict[str, Any]] = mapped_column(json_type, nullable=False)
    created_at = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


def init_database() -> None:
    with engine.begin() as connection:
        connection.execute(text("CREATE EXTENSION IF NOT EXISTS pgcrypto"))
        connection.execute(text("""
            CREATE TABLE IF NOT EXISTS interview_analysis (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                session_id UUID NOT NULL UNIQUE,
                transcript TEXT NOT NULL,
                analysis_result JSONB NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
        """))
        connection.execute(text("""
            CREATE TABLE IF NOT EXISTS interview_transcript_segments (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                session_id UUID NOT NULL,
                segment_index INTEGER NOT NULL,
                start_second NUMERIC NOT NULL,
                end_second NUMERIC NOT NULL,
                transcript TEXT NOT NULL,
                analysis_result JSONB NOT NULL,
                recorded_video_url TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                UNIQUE (session_id, segment_index)
            )
        """))


def ping_database() -> None:
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))


def save_analysis(session_id: UUID, transcript: str, analysis_result: dict[str, Any]) -> None:
    with engine.begin() as connection:
        connection.execute(
            text("""
                INSERT INTO interview_analysis (session_id, transcript, analysis_result)
                VALUES (:session_id, :transcript, CAST(:analysis_result AS JSONB))
                ON CONFLICT (session_id)
                DO UPDATE SET
                    transcript = EXCLUDED.transcript,
                    analysis_result = EXCLUDED.analysis_result,
                    created_at = now()
            """),
            {
                "session_id": str(session_id),
                "transcript": transcript,
                "analysis_result": json.dumps(analysis_result),
            },
        )


def save_segment_analysis(
    session_id: UUID,
    segment_index: int,
    start_second: float,
    end_second: float,
    transcript: str,
    analysis_result: dict[str, Any],
    recorded_video_url: str,
) -> None:
    with engine.begin() as connection:
        connection.execute(
            text("""
                INSERT INTO interview_transcript_segments (
                    session_id,
                    segment_index,
                    start_second,
                    end_second,
                    transcript,
                    analysis_result,
                    recorded_video_url
                )
                VALUES (
                    :session_id,
                    :segment_index,
                    :start_second,
                    :end_second,
                    :transcript,
                    CAST(:analysis_result AS JSONB),
                    :recorded_video_url
                )
                ON CONFLICT (session_id, segment_index)
                DO UPDATE SET
                    start_second = EXCLUDED.start_second,
                    end_second = EXCLUDED.end_second,
                    transcript = EXCLUDED.transcript,
                    analysis_result = EXCLUDED.analysis_result,
                    recorded_video_url = EXCLUDED.recorded_video_url,
                    created_at = now()
            """),
            {
                "session_id": str(session_id),
                "segment_index": segment_index,
                "start_second": start_second,
                "end_second": end_second,
                "transcript": transcript,
                "analysis_result": json.dumps(analysis_result),
                "recorded_video_url": recorded_video_url,
            },
        )


def rebuild_session_analysis_from_segments(session_id: UUID, *, evaluate_ai: bool = True) -> None:
    with engine.begin() as connection:
        rows = connection.execute(
            text("""
                SELECT start_second, end_second, transcript, analysis_result
                FROM interview_transcript_segments
                WHERE session_id = :session_id
                ORDER BY segment_index ASC
            """),
            {"session_id": str(session_id)},
        ).mappings().all()

        if not rows:
            return

        if not _interview_session_exists(connection, session_id):
            logger.warning("Interview session bulunamadı, aggregate analiz atlandı: %s", session_id)
            return

        timed_transcript = "\n".join(
            f"[{int(row['start_second'])}-{int(row['end_second'])}s] {row['transcript']}".strip()
            for row in rows
        )
        evaluation_transcript = "\n".join(str(row["transcript"] or "").strip() for row in rows).strip()
        analyses = [_as_dict(row["analysis_result"]) for row in rows]
        total_words = sum(int(analysis.get("total_words", 0)) for analysis in analyses)
        duration = max(float(row["end_second"]) for row in rows)
        filler_words: dict[str, int] = {}
        pause_count = 0
        pause_seconds = 0.0

        for analysis in analyses:
            pause_count += int(analysis.get("pause_count", 0))
            pause_seconds += float(analysis.get("pause_seconds", 0))
            for word, count in (analysis.get("filler_words", {}) or {}).items():
                filler_words[word] = filler_words.get(word, 0) + int(count)

        minutes = duration / 60 if duration else 0
        wpm = round(total_words / minutes, 2) if minutes else 0
        filler_total = sum(filler_words.values())
        aggregate = {
            "wpm": wpm,
            "total_words": total_words,
            "duration_seconds": duration,
            "pause_count": pause_count,
            "pause_seconds": round(pause_seconds, 2),
            "pause_ratio": round(pause_seconds / duration, 4) if duration else 0,
            "filler_words": dict(sorted(filler_words.items())),
            "filler_word_count": filler_total,
            "filler_word_ratio": round(filler_total / total_words, 4) if total_words else 0,
            "segment_count": len(rows),
        }
        aggregate["overall_score"] = calculate_overall_score(
            aggregate["wpm"],
            aggregate["pause_ratio"],
            aggregate["filler_word_ratio"],
        )
        if evaluate_ai:
            aggregate["ai_evaluation"] = evaluate_interview(evaluation_transcript, aggregate)
        else:
            aggregate["ai_evaluation"] = {
                "score": None,
                "reason": "AI değerlendirmesi mülakat kaydı tamamlanınca oluşturulacak.",
                "strengths": [],
                "improvements": [],
                "source": "pending",
                "model": None,
            }

        save_analysis(session_id, timed_transcript, aggregate)


def _interview_session_exists(connection, session_id: UUID) -> bool:
    try:
        return connection.execute(
            text("SELECT 1 FROM interview_sessions WHERE id = :session_id"),
            {"session_id": str(session_id)},
        ).first() is not None
    except SQLAlchemyError:
        return True


def _as_dict(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        return json.loads(value)
    return {}
