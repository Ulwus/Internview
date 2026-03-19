from fastapi import FastAPI
from contextlib import asynccontextmanager
import os
import httpx
from sqlalchemy import create_engine, text

# ── Database ────────────────────────────────────────────
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://internview:internview_password@localhost:5432/internview",
)
engine = create_engine(DATABASE_URL, pool_pre_ping=True)

# ── Consul ──────────────────────────────────────────────
CONSUL_URL = os.getenv("CONSUL_URL", "http://localhost:8500")

app = FastAPI(title="Internview AI Analysis Service", version="1.0.0")


@app.get("/health")
async def health_check():
    """Health endpoint that pings PostgreSQL and Consul."""
    checks: dict[str, str] = {}

    # PostgreSQL ping
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        checks["postgresql"] = "UP"
    except Exception as exc:
        checks["postgresql"] = f"DOWN ({exc.__class__.__name__})"

    # Consul ping
    try:
        async with httpx.AsyncClient(timeout=3) as client:
            resp = await client.get(f"{CONSUL_URL}/v1/status/leader")
            checks["consul"] = "UP" if resp.status_code == 200 else "DOWN"
    except Exception as exc:
        checks["consul"] = f"DOWN ({exc.__class__.__name__})"

    overall = "healthy" if all(v == "UP" for v in checks.values()) else "degraded"
    return {"status": overall, "components": checks}


@app.post("/api/v1/analyze")
def analyze_video():
    # TODO: Implement Whisper audio extraction and speech-to-text here
    return {"message": "Analysis endpoint placeholder"}
