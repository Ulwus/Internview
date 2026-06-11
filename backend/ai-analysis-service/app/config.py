import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql://internview:internview_password@localhost:5432/internview",
    )
    consul_url: str = os.getenv("CONSUL_URL", "http://localhost:8500")
    kafka_bootstrap_servers: str = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:29092")
    interview_events_topic: str = os.getenv("INTERVIEW_EVENTS_TOPIC", "interview-events")
    recording_segments_topic: str = os.getenv("RECORDING_SEGMENTS_TOPIC", "recording-segments")
    analysis_events_topic: str = os.getenv("ANALYSIS_EVENTS_TOPIC", "analysis-events")
    kafka_group_id: str = os.getenv("KAFKA_GROUP_ID", "ai-analysis-service")
    enable_kafka_consumer: bool = os.getenv("ENABLE_KAFKA_CONSUMER", "false").lower() == "true"
    whisper_model: str = os.getenv("WHISPER_MODEL", "small")
    whisper_language: str = os.getenv("WHISPER_LANGUAGE", "tr")
    whisper_backend: str = os.getenv("WHISPER_BACKEND", "openai")
    whisper_cpp_server_url: str | None = os.getenv("WHISPER_CPP_SERVER_URL")
    preload_whisper_model: bool = os.getenv("PRELOAD_WHISPER_MODEL", "true").lower() == "true"
    whisper_download_root: str | None = os.getenv("WHISPER_DOWNLOAD_ROOT")
    work_dir: str = os.getenv("AI_ANALYSIS_WORK_DIR", "/tmp/internview-ai-analysis")
    s3_endpoint: str | None = os.getenv("S3_ENDPOINT")
    s3_region: str = os.getenv("S3_REGION", "us-east-1")
    s3_bucket: str = os.getenv("S3_BUCKET", "internview-recordings")
    s3_access_key: str | None = os.getenv("S3_ACCESS_KEY")
    s3_secret_key: str | None = os.getenv("S3_SECRET_KEY")
    s3_force_path_style: bool = os.getenv("S3_FORCE_PATH_STYLE", "false").lower() == "true"
    groq_api_key: str | None = os.getenv("GROQ_API_KEY")
    groq_base_url: str = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
    groq_model: str = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")
    enable_llm_evaluation: bool = os.getenv("ENABLE_LLM_EVALUATION", "true").lower() == "true"


settings = Settings()
