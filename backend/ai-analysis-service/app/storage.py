from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from urllib.parse import urlparse

import boto3
import httpx

from app.config import settings


def ensure_work_dir() -> Path:
    work_dir = Path(settings.work_dir)
    work_dir.mkdir(parents=True, exist_ok=True)
    return work_dir


def download_recording(recorded_video_url: str, session_id: str) -> Path:
    work_dir = ensure_work_dir()
    parsed = urlparse(recorded_video_url)
    target = work_dir / f"{session_id}{Path(parsed.path).suffix or '.webm'}"

    if parsed.scheme == "s3":
        client = boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint,
            region_name=settings.s3_region,
            aws_access_key_id=settings.s3_access_key,
            aws_secret_access_key=settings.s3_secret_key,
        )
        client.download_file(parsed.netloc, parsed.path.lstrip("/"), str(target))
        return target

    if parsed.scheme in {"http", "https"}:
        with httpx.stream("GET", recorded_video_url, timeout=60) as response:
            response.raise_for_status()
            with target.open("wb") as file:
                for chunk in response.iter_bytes():
                    file.write(chunk)
        return target

    if parsed.scheme == "file":
        shutil.copyfile(parsed.path, target)
        return target

    source = Path(recorded_video_url)
    if source.exists():
        shutil.copyfile(source, target)
        return target

    raise ValueError(f"Desteklenmeyen kayıt URL'i: {recorded_video_url}")


def extract_audio(video_path: Path, session_id: str) -> Path:
    audio_path = ensure_work_dir() / f"{session_id}.wav"
    command = [
        "ffmpeg",
        "-y",
        "-i",
        str(video_path),
        "-vn",
        "-acodec",
        "pcm_s16le",
        "-ar",
        "16000",
        "-ac",
        "1",
        str(audio_path),
    ]
    subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return audio_path


def cleanup_files(*paths: Path) -> None:
    for path in paths:
        try:
            os.remove(path)
        except OSError:
            pass
