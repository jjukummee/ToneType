import json
from fastapi.testclient import TestClient

from app.main import app

from .audio_factory import sine_wav

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.json() == {"status": "ok"}
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-request-id"]


def test_readiness_reports_missing_speech_configuration(monkeypatch) -> None:
    for key in (
        "GOOGLE_SPEECH_RECOGNIZER",
        "GOOGLE_CLOUD_PROJECT_NUMBER",
        "GOOGLE_CLOUD_LOCATION",
        "GOOGLE_SPEECH_RECOGNIZER_ID",
    ):
        monkeypatch.delenv(key, raising=False)

    response = client.get("/ready")

    assert response.status_code == 503
    assert response.json()["reason"] == "speech_configuration"


def test_analyze_endpoint_with_timestamps_and_debug() -> None:
    timestamps = [
        {"text": "오늘", "start": 0.0, "end": 0.4},
        {"text": "말했어", "start": 0.5, "end": 0.9},
    ]
    response = client.post(
        "/api/prosody/analyze?debug=true",
        files={"audio": ("sample.wav", sine_wav(), "audio/wav")},
        data={"language": "ko-KR", "timestamps": json.dumps(timestamps)},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["utterance"]["volume"] >= 0
    assert len(payload["segments"]) == 2
    assert payload["debug"]["duration_seconds"] == 1.0


def test_endpoint_returns_structured_audio_error() -> None:
    response = client.post(
        "/api/prosody/analyze",
        files={"audio": ("bad.wav", b"broken", "audio/wav")},
    )
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_audio"
