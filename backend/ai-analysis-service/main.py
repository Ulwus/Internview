from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI

from app.config import settings
from app.database import init_database, ping_database
from app.kafka_bus import kafka_bus
from app.pipeline import analyze_interview_completed, analyze_recording_segment, analyze_request
from app.schemas import AnalyzeRequest, AnalyzeResponse


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_database()
    kafka_bus.start_consumer(handle_kafka_event)
    yield
    kafka_bus.stop()


def handle_kafka_event(event_name, payload):
    if event_name == "interview_completed":
        return analyze_interview_completed(payload)
    if event_name == "recording_segment":
        return analyze_recording_segment(payload)
    return None


app = FastAPI(
    title="Internview AI Analysis Service",
    version="1.0.0",
    lifespan=lifespan,
)


@app.get("/health")
async def health_check():
    checks: dict[str, str] = {}

    try:
        ping_database()
        checks["postgresql"] = "UP"
    except Exception as exc:
        checks["postgresql"] = f"DOWN ({exc.__class__.__name__})"

    try:
        async with httpx.AsyncClient(timeout=3) as client:
            resp = await client.get(f"{settings.consul_url}/v1/status/leader")
            checks["consul"] = "UP" if resp.status_code == 200 else "DOWN"
    except Exception as exc:
        checks["consul"] = f"DOWN ({exc.__class__.__name__})"

    overall = "healthy" if all(value == "UP" for value in checks.values()) else "degraded"
    return {"status": overall, "components": checks}


@app.post("/api/v1/analyze", response_model=AnalyzeResponse)
def analyze_video(request: AnalyzeRequest) -> AnalyzeResponse:
    return analyze_request(request)
