from __future__ import annotations

import json
import logging
from typing import Any

import httpx

from app.config import settings


logger = logging.getLogger(__name__)


def evaluate_interview(transcript: str, metrics: dict[str, Any]) -> dict[str, Any]:
    if not transcript.strip():
        return _fallback_evaluation(metrics, reason="Transkript bulunamadığı için metrik tabanlı değerlendirme yapıldı.")

    if not settings.enable_llm_evaluation:
        return _fallback_evaluation(metrics, reason="LLM değerlendirmesi kapalı olduğu için metrik tabanlı değerlendirme yapıldı.")

    if not settings.groq_api_key:
        return _fallback_evaluation(metrics, reason="GROQ_API_KEY tanımlı olmadığı için metrik tabanlı değerlendirme yapıldı.")

    try:
        return _evaluate_with_groq(transcript, metrics)
    except Exception as exc:
        logger.warning("Groq değerlendirmesi başarısız, fallback kullanılacak: %s", exc)
        return _fallback_evaluation(metrics, reason="AI değerlendirmesi alınamadığı için metrik tabanlı değerlendirme yapıldı.")


def _evaluate_with_groq(transcript: str, metrics: dict[str, Any]) -> dict[str, Any]:
    prompt = {
        "role": "user",
        "content": (
            "Aşağıdaki Türkçe mülakat transkriptini ve konuşma metriklerini değerlendir. "
            "Mülakatçı gibi düşün: adayın iletişim netliği, teknik/mesleki cevap kalitesi, özgüveni, "
            "dolgu kelime kullanımı ve akıcılığına bak. Sadece JSON döndür.\n\n"
            "JSON şeması: {\"score\": number, \"reason\": string, \"strengths\": string[], "
            "\"improvements\": string[]}. score 1-10 arasında tek ondalıklı olabilir.\n\n"
            f"Metrikler:\n{json.dumps(metrics, ensure_ascii=False)}\n\n"
            f"Transkript:\n{transcript[:12000]}"
        ),
    }
    response = httpx.post(
        f"{settings.groq_base_url.rstrip('/')}/chat/completions",
        headers={
            "Authorization": f"Bearer {settings.groq_api_key}",
            "Content-Type": "application/json",
        },
        json={
            "model": settings.groq_model,
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "Sen iş mülakatı değerlendiren deneyimli bir yapay zeka koçusun. "
                        "Cevabın yalnızca geçerli JSON olmalı."
                    ),
                },
                prompt,
            ],
            "temperature": 0.2,
            "response_format": {"type": "json_object"},
        },
        timeout=30,
    )
    response.raise_for_status()
    payload = response.json()
    content = payload["choices"][0]["message"]["content"]
    parsed = json.loads(content)
    return _normalize_evaluation(parsed, source="groq", model=settings.groq_model)


def _fallback_evaluation(metrics: dict[str, Any], reason: str) -> dict[str, Any]:
    score_100 = float(metrics.get("overall_score") or 0)
    score_10 = max(1.0, min(10.0, round(score_100 / 10, 1)))
    wpm = float(metrics.get("wpm") or 0)
    filler_ratio = float(metrics.get("filler_word_ratio") or 0)
    pause_ratio = float(metrics.get("pause_ratio") or 0)

    strengths: list[str] = []
    improvements: list[str] = []
    if 110 <= wpm <= 180:
        strengths.append("Konuşma hızı anlaşılır aralıkta.")
    elif wpm:
        improvements.append("Konuşma hızını daha dengeli tutması faydalı olur.")
    if filler_ratio <= 0.04:
        strengths.append("Dolgu kelime kullanımı düşük.")
    else:
        improvements.append("Dolgu kelimeleri azaltarak cevaplarını daha net verebilir.")
    if pause_ratio <= 0.15:
        strengths.append("Cevap akışı genel olarak kesintisiz.")
    else:
        improvements.append("Uzun duraksamaları azaltıp cevap yapısını önceden kurabilir.")

    if not strengths:
        strengths.append("Transkript ve metrikler üzerinden temel değerlendirme oluşturuldu.")
    if not improvements:
        improvements.append("Daha fazla somut örnekle cevaplarını güçlendirebilir.")

    return {
        "score": score_10,
        "reason": reason,
        "strengths": strengths[:3],
        "improvements": improvements[:3],
        "source": "fallback",
        "model": None,
    }


def _normalize_evaluation(value: dict[str, Any], source: str, model: str | None) -> dict[str, Any]:
    raw_score = value.get("score", 0)
    try:
        score = round(float(raw_score), 1)
    except (TypeError, ValueError):
        score = 0
    score = max(1.0, min(10.0, score))

    reason = str(value.get("reason") or "AI değerlendirmesi oluşturuldu.").strip()
    strengths = _string_list(value.get("strengths"))
    improvements = _string_list(value.get("improvements"))
    return {
        "score": score,
        "reason": reason,
        "strengths": strengths[:3],
        "improvements": improvements[:3],
        "source": source,
        "model": model,
    }


def _string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]
