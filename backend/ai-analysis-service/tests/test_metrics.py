from app.metrics import calculate_speech_metrics


def test_calculate_speech_metrics_counts_words_pauses_and_fillers():
    transcript = "Merhaba eee bugün yani teknik görüşmeye başladık"
    segments = [
        {"start": 0.0, "end": 2.0},
        {"start": 3.5, "end": 6.0},
    ]

    result = calculate_speech_metrics(transcript, segments, duration_seconds=30)

    assert result["total_words"] == 7
    assert result["pause_count"] == 1
    assert result["pause_seconds"] == 1.5
    assert result["filler_words"] == {"eee": 1, "yani": 1}
    assert result["filler_word_count"] == 2
    assert result["wpm"] == 14
