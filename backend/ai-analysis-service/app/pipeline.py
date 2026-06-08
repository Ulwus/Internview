from __future__ import annotations

from functools import lru_cache
from typing import Any

import whisper

from app.config import settings
from app.database import rebuild_session_analysis_from_segments, save_analysis, save_segment_analysis
from app.kafka_bus import kafka_bus
from app.metrics import calculate_speech_metrics
from app.schemas import AnalyzeRequest, AnalyzeResponse, InterviewCompletedPayload, RecordingSegmentPayload
from app.storage import cleanup_files, download_recording, extract_audio


@lru_cache(maxsize=1)
def whisper_model():
    return whisper.load_model(settings.whisper_model, download_root=settings.whisper_download_root)


def analyze_request(request: AnalyzeRequest) -> AnalyzeResponse:
    video_path = download_recording(request.recorded_video_url, str(request.session_id))
    audio_path = extract_audio(video_path, str(request.session_id))
    try:
        result: dict[str, Any] = whisper_model().transcribe(str(audio_path), fp16=False)
        transcript = str(result.get("text") or "").strip()
        segments = result.get("segments") or []
        analysis = calculate_speech_metrics(transcript, segments, request.duration_seconds)
        save_analysis(request.session_id, transcript, analysis)
        kafka_bus.publish_analysis_completed(str(request.session_id), str(request.candidate_id) if request.candidate_id else None, analysis)
        return AnalyzeResponse(session_id=request.session_id, transcript=transcript, analysis=analysis)
    finally:
        cleanup_files(video_path, audio_path)


def analyze_interview_completed(payload: InterviewCompletedPayload) -> AnalyzeResponse:
    return analyze_request(AnalyzeRequest(
        session_id=payload.session_id,
        booking_id=payload.booking_id,
        candidate_id=payload.candidate_id,
        expert_id=payload.expert_id,
        duration_seconds=payload.duration_seconds,
        recorded_video_url=payload.recorded_video_url,
    ))


def analyze_recording_segment(payload: RecordingSegmentPayload) -> AnalyzeResponse:
    request = AnalyzeRequest(
        session_id=payload.session_id,
        duration_seconds=payload.duration_seconds,
        recorded_video_url=f"s3://{settings.s3_bucket}/{payload.s3_key}",
    )
    segment_file_id = f"{request.session_id}-{payload.segment_index}"
    video_path = download_recording(request.recorded_video_url, segment_file_id)
    audio_path = extract_audio(video_path, segment_file_id)
    try:
        result: dict[str, Any] = whisper_model().transcribe(str(audio_path), fp16=False)
        transcript = str(result.get("text") or "").strip()
        segments = result.get("segments") or []
        analysis = calculate_speech_metrics(transcript, segments, request.duration_seconds)
        save_segment_analysis(
            payload.session_id,
            payload.segment_index,
            payload.start_second,
            payload.end_second,
            transcript,
            analysis,
            payload.recorded_video_url,
        )
        rebuild_session_analysis_from_segments(payload.session_id)
        return AnalyzeResponse(session_id=payload.session_id, transcript=transcript, analysis=analysis)
    finally:
        cleanup_files(video_path, audio_path)
