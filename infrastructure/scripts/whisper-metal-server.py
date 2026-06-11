#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import tempfile
import uuid


SCRIPT_PATH = Path(__file__).resolve()
ROOT_DIR = SCRIPT_PATH.parents[2] if len(SCRIPT_PATH.parents) > 2 else Path("/app")
WHISPER_CPP_DIR = Path(os.getenv("WHISPER_CPP_DIR", ROOT_DIR / ".local/tools/whisper.cpp"))
WHISPER_BIN = Path(os.getenv("WHISPER_CPP_BIN", WHISPER_CPP_DIR / "build/bin/whisper-cli"))
WHISPER_MODEL = Path(
    os.getenv(
        "WHISPER_CPP_MODEL",
        WHISPER_CPP_DIR / "models/ggml-large-v3-turbo-q5_0.bin",
    )
)
HOST_WORK_DIR = Path(os.getenv("AI_ANALYSIS_WORK_HOST_DIR", ROOT_DIR / ".local/share/ai-analysis-work")).resolve()
CONTAINER_WORK_DIR = os.getenv("AI_ANALYSIS_WORK_CONTAINER_DIR", "/work").rstrip("/")
PORT = int(os.getenv("WHISPER_CPP_SERVER_PORT", "8787"))
HOST = os.getenv("WHISPER_CPP_SERVER_HOST", "127.0.0.1")


def map_container_path(audio_path: str) -> Path:
    if audio_path.startswith(f"{CONTAINER_WORK_DIR}/"):
        relative = audio_path[len(CONTAINER_WORK_DIR) + 1 :]
        mapped = (HOST_WORK_DIR / relative).resolve()
    else:
        mapped = Path(audio_path).resolve()

    try:
        mapped.relative_to(HOST_WORK_DIR)
    except ValueError as exc:
        raise ValueError(f"audio_path must be inside {HOST_WORK_DIR}") from exc

    if not mapped.is_file():
        raise FileNotFoundError(f"audio file not found: {mapped}")

    return mapped


def load_whisper_json(output_base: Path) -> dict:
    json_path = output_base.with_suffix(".json")
    txt_path = output_base.with_suffix(".txt")

    if json_path.is_file():
        with json_path.open("r", encoding="utf-8") as fh:
            payload = json.load(fh)
        source_segments = payload.get("segments") or payload.get("transcription") or []
        normalized_segments = []
        for segment in source_segments:
            offsets = segment.get("offsets") or {}
            start = segment.get("start")
            end = segment.get("end")
            if start is None and "from" in offsets:
                start = float(offsets["from"]) / 1000
            if end is None and "to" in offsets:
                end = float(offsets["to"]) / 1000
            normalized = dict(segment)
            normalized["start"] = float(start or 0)
            normalized["end"] = float(end or 0)
            normalized["text"] = str(segment.get("text") or "").strip()
            normalized_segments.append(normalized)

        payload["segments"] = normalized_segments
        if "text" not in payload:
            payload["text"] = " ".join(
                str(segment.get("text") or "").strip()
                for segment in normalized_segments
            ).strip()
        return payload

    text = txt_path.read_text(encoding="utf-8").strip() if txt_path.is_file() else ""
    return {"text": text, "segments": [{"start": 0, "end": 0, "text": text}] if text else []}


def transcribe(audio_path: Path, language: str) -> dict:
    if not WHISPER_BIN.is_file():
        raise FileNotFoundError(f"whisper-cli not found: {WHISPER_BIN}")
    if not WHISPER_MODEL.is_file():
        raise FileNotFoundError(f"model not found: {WHISPER_MODEL}")

    output_base = Path(tempfile.gettempdir()) / f"internview-whisper-{uuid.uuid4()}"
    cmd = [
        str(WHISPER_BIN),
        "-m",
        str(WHISPER_MODEL),
        "-f",
        str(audio_path),
        "-l",
        language,
        "--no-flash-attn",
        "--prompt",
        "Bu kayıt Türkçe bir iş mülakatıdır. Duyulan Türkçe konuşmayı Türkçe olarak yaz.",
        "-oj",
        "-otxt",
        "-of",
        str(output_base),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return load_whisper_json(output_base)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path != "/health":
            self.send_error(404)
            return
        ready = WHISPER_BIN.is_file() and WHISPER_MODEL.is_file()
        self.write_json(
            {
                "status": "UP" if ready else "DOWN",
                "binary": str(WHISPER_BIN),
                "model": str(WHISPER_MODEL),
            },
            status=200 if ready else 503,
        )

    def do_POST(self) -> None:
        if self.path != "/transcribe":
            self.send_error(404)
            return

        try:
            length = int(self.headers.get("content-length", "0"))
            payload = json.loads(self.rfile.read(length) or b"{}")
            audio_path = map_container_path(str(payload["audio_path"]))
            language = str(payload.get("language") or "tr")
            self.write_json(transcribe(audio_path, language))
        except Exception as exc:
            self.write_json({"error": str(exc)}, status=500)

    def log_message(self, fmt: str, *args) -> None:
        print(f"{self.address_string()} - {fmt % args}", flush=True)

    def write_json(self, payload: dict, status: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    HOST_WORK_DIR.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"whisper-metal-server listening on http://{HOST}:{PORT}", flush=True)
    print(f"work dir: {HOST_WORK_DIR}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
