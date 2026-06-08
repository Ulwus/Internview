from __future__ import annotations

import json
import logging
import threading
import time
from datetime import UTC, datetime
from uuid import uuid4

from kafka import KafkaConsumer, KafkaProducer

from app.config import settings
from app.schemas import InterviewCompletedEvent, RecordingSegmentUploadedEvent

logger = logging.getLogger(__name__)


class KafkaBus:
    def __init__(self) -> None:
        self._producer: KafkaProducer | None = None
        self._consumer_thread: threading.Thread | None = None
        self._stop = threading.Event()

    def producer(self) -> KafkaProducer:
        if self._producer is None:
            self._producer = KafkaProducer(
                bootstrap_servers=settings.kafka_bootstrap_servers,
                value_serializer=lambda value: json.dumps(value).encode("utf-8"),
                key_serializer=lambda value: value.encode("utf-8") if value else None,
            )
        return self._producer

    def publish_analysis_completed(self, session_id: str, candidate_id: str | None, analysis: dict) -> None:
        if not candidate_id:
            return
        event = {
            "event_type": "ANALYSIS_COMPLETED",
            "event_id": f"evt-{uuid4()}",
            "timestamp": datetime.now(UTC).isoformat(),
            "payload": {
                "session_id": session_id,
                "candidate_id": candidate_id,
                "overall_score": analysis.get("overall_score", 0),
                "analysis_summary": {
                    "wpm": analysis.get("wpm", 0),
                    "pause_ratio": analysis.get("pause_ratio", 0),
                    "filler_word_ratio": analysis.get("filler_word_ratio", 0),
                },
            },
        }
        producer = self.producer()
        producer.send(settings.analysis_events_topic, key=session_id, value=event)
        producer.flush(timeout=10)

    def start_consumer(self, handler) -> None:
        if not settings.enable_kafka_consumer or self._consumer_thread:
            return
        self._consumer_thread = threading.Thread(
            target=self._consume_loop,
            args=(handler,),
            name="interview-events-consumer",
            daemon=True,
        )
        self._consumer_thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._producer:
            self._producer.close(timeout=5)

    def _consume_loop(self, handler) -> None:
        consumer = None
        while not self._stop.is_set() and consumer is None:
            try:
                consumer = KafkaConsumer(
                    settings.interview_events_topic,
                    settings.recording_segments_topic,
                    bootstrap_servers=settings.kafka_bootstrap_servers,
                    group_id=settings.kafka_group_id,
                    auto_offset_reset="earliest",
                    enable_auto_commit=False,
                    value_deserializer=lambda value: json.loads(value.decode("utf-8")),
                )
            except Exception:
                logger.exception("Kafka consumer başlatılamadı, 5 saniye sonra tekrar denenecek")
                time.sleep(5)

        if consumer is None:
            return

        for message in consumer:
            if self._stop.is_set():
                break
            try:
                event_type = message.value.get("event_type")
                if event_type == "INTERVIEW_COMPLETED":
                    event = InterviewCompletedEvent.model_validate(message.value)
                    handler("interview_completed", event.payload)
                elif event_type == "RECORDING_SEGMENT_UPLOADED":
                    event = RecordingSegmentUploadedEvent.model_validate(message.value)
                    handler("recording_segment", event.payload)
                consumer.commit()
            except Exception:
                logger.exception("InterviewCompletedEvent işlenemedi")


kafka_bus = KafkaBus()
