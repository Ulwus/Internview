from __future__ import annotations

import re
from collections import Counter
from typing import Any


FILLER_WORDS = (
    "eee",
    "ee",
    "ııı",
    "hmm",
    "hımm",
    "yani",
    "şey",
    "sey",
    "aslında",
    "hani",
    "böyle",
    "like",
    "um",
    "uh",
)

WORD_RE = re.compile(r"[\wçğıöşüÇĞİÖŞÜ']+", re.UNICODE)


def calculate_speech_metrics(
    transcript: str,
    segments: list[dict[str, Any]],
    duration_seconds: float | None,
    pause_threshold_seconds: float = 1.0,
) -> dict[str, Any]:
    words = WORD_RE.findall(transcript.lower())
    total_words = len(words)
    inferred_duration = infer_duration(segments)
    duration = float(duration_seconds or inferred_duration or 0)
    minutes = duration / 60 if duration > 0 else 0
    wpm = round(total_words / minutes, 2) if minutes else 0

    pauses = detect_pauses(segments, pause_threshold_seconds)
    pause_seconds = round(sum(pause["duration_seconds"] for pause in pauses), 2)
    pause_count = len(pauses)
    pause_ratio = round(pause_seconds / duration, 4) if duration else 0

    filler_counter = Counter(word for word in words if word in FILLER_WORDS)
    filler_total = sum(filler_counter.values())
    filler_ratio = round(filler_total / total_words, 4) if total_words else 0

    return {
        "wpm": wpm,
        "total_words": total_words,
        "duration_seconds": round(duration, 2),
        "pause_count": pause_count,
        "pause_seconds": pause_seconds,
        "pause_ratio": pause_ratio,
        "filler_words": dict(sorted(filler_counter.items())),
        "filler_word_count": filler_total,
        "filler_word_ratio": filler_ratio,
        "overall_score": calculate_overall_score(wpm, pause_ratio, filler_ratio),
        "pauses": pauses,
    }


def infer_duration(segments: list[dict[str, Any]]) -> float:
    if not segments:
        return 0
    return max(float(segment.get("end") or 0) for segment in segments)


def detect_pauses(
    segments: list[dict[str, Any]],
    pause_threshold_seconds: float,
) -> list[dict[str, float]]:
    ordered = sorted(segments, key=lambda segment: float(segment.get("start") or 0))
    pauses: list[dict[str, float]] = []

    for previous, current in zip(ordered, ordered[1:]):
        previous_end = float(previous.get("end") or 0)
        current_start = float(current.get("start") or 0)
        gap = round(current_start - previous_end, 2)
        if gap >= pause_threshold_seconds:
            pauses.append({
                "start": round(previous_end, 2),
                "end": round(current_start, 2),
                "duration_seconds": gap,
            })
    return pauses


def calculate_overall_score(wpm: float, pause_ratio: float, filler_ratio: float) -> float:
    ideal_wpm = 145
    wpm_penalty = min(abs(wpm - ideal_wpm) / ideal_wpm, 1) * 35
    pause_penalty = min(pause_ratio / 0.25, 1) * 35
    filler_penalty = min(filler_ratio / 0.08, 1) * 30
    return round(max(0, 100 - wpm_penalty - pause_penalty - filler_penalty), 2)
