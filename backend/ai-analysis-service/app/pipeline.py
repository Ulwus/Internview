from __future__ import annotations

from functools import lru_cache
import logging
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


def transcribe_audio(audio_path: str) -> dict[str, Any]:
    return whisper_model().transcribe(
        audio_path,
        fp16=False,
        language=settings.whisper_language,
        task="transcribe",
        temperature=0,
        condition_on_previous_text=False,
        no_speech_threshold=0.6,
        logprob_threshold=-1.0,
        compression_ratio_threshold=2.4,
        initial_prompt=(
            "Bu kayıt Türkçe bir iş mülakatıdır. "
            "Duyulan Türkçe konuşmayı Türkçe olarak yaz. İngilizceye çevirme."
        ),
    )


def clean_transcription(result: dict[str, Any]) -> tuple[str, list[dict[str, Any]]]:
    cleaned_segments: list[dict[str, Any]] = []
    for segment in result.get("segments") or []:
        no_speech_prob = float(segment.get("no_speech_prob") or 0)
        avg_logprob = float(segment.get("avg_logprob") or 0)
        text = str(segment.get("text") or "").strip()
        if text and no_speech_prob < 0.75 and avg_logprob > -2.0:
            cleaned_segments.append(segment)

    transcript = " ".join(str(segment.get("text") or "").strip() for segment in cleaned_segments).strip()
    return transcript, cleaned_segments


def analyze_request(request: AnalyzeRequest) -> AnalyzeResponse:
    if not request.recorded_video_url or request.recorded_video_url == "." or request.recorded_video_url.lower() == "none":
        logging.warning(f"Skipping analysis for session {request.session_id}: invalid recorded_video_url ({request.recorded_video_url})")
        return AnalyzeResponse(session_id=request.session_id, transcript="", analysis={})

    video_path = download_recording(request.recorded_video_url, str(request.session_id))
    audio_path = extract_audio(video_path, str(request.session_id))
    try:
        result = transcribe_audio(str(audio_path))
        transcript, segments = clean_transcription(result)
        analysis = calculate_speech_metrics(transcript, segments, request.duration_seconds)
        save_analysis(request.session_id, transcript, analysis)
        kafka_bus.publish_analysis_completed(str(request.session_id), str(request.candidate_id) if request.candidate_id else None, analysis)
        return AnalyzeResponse(session_id=request.session_id, transcript=transcript, analysis=analysis)
    finally:
        cleanup_files(video_path, audio_path)


def analyze_interview_completed(payload: InterviewCompletedPayload) -> AnalyzeResponse:
    if payload.recorded_video_url.endswith("/manifest.json"):
        rebuild_session_analysis_from_segments(payload.session_id)
        return AnalyzeResponse(session_id=payload.session_id, transcript="", analysis={})

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
        result = transcribe_audio(str(audio_path))
        transcript, segments = clean_transcription(result)
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
