from fastapi.testclient import TestClient

from app.api.routes.conversation import get_kinetic_director, get_speech_transcriber
from app.main import app
from app.schemas.kinetic import KineticPlanResponse, KineticSegmentResponse
from app.schemas.prosody import WordTimestamp
from app.schemas.prosody import ProsodyResponse
from app.services.speech import TranscriptionResult

from .audio_factory import sine_wav


class FakeSpeechTranscriber:
    def transcribe(self, content: bytes, *, language: str) -> TranscriptionResult:
        assert content
        return TranscriptionResult(
            text="내일 말고 오늘이라고 했어",
            language="ko-KR",
            words=[
                WordTimestamp(text="내일", start=0.0, end=0.2),
                WordTimestamp(text="말고", start=0.24, end=0.42),
                WordTimestamp(text="오늘이라고", start=0.46, end=0.72),
                WordTimestamp(text="했어", start=0.76, end=0.96),
            ],
        )


class FakeKineticDirector:
    def generate(
        self,
        *,
        transcript: str,
        language: str,
        conversation_context: str,
        prosody: ProsodyResponse,
    ) -> KineticPlanResponse:
        assert transcript
        assert language == "ko-KR"
        assert conversation_context == "일상"
        assert prosody.segments
        return KineticPlanResponse(
            model="gemini-test",
            interpretation="대조되는 핵심 표현을 강조합니다.",
            segments=[
                KineticSegmentResponse(
                    text=transcript,
                    motion="impact",
                    intensity="strong",
                )
            ],
        )


client = TestClient(app)


def test_conversation_endpoint_combines_stt_and_prosody() -> None:
    app.dependency_overrides[get_speech_transcriber] = FakeSpeechTranscriber
    try:
        response = client.post(
            "/api/conversations/analyze?debug=true",
            files={"audio": ("sample.wav", sine_wav(), "audio/wav")},
            data={"source_language": "ko-KR", "target_language": "ko-KR"},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    payload = response.json()
    assert payload["transcript"] == "내일 말고 오늘이라고 했어"
    assert len(payload["words"]) == 4
    assert len(payload["prosody"]["segments"]) == 4


def test_conversation_endpoint_rejects_unconfigured_translation() -> None:
    app.dependency_overrides[get_speech_transcriber] = FakeSpeechTranscriber
    try:
        response = client.post(
            "/api/conversations/analyze",
            files={"audio": ("sample.wav", sine_wav(), "audio/wav")},
            data={"source_language": "ko-KR", "target_language": "en-US"},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "translation_not_configured"


def test_conversation_endpoint_returns_hybrid_kinetic_plan() -> None:
    app.dependency_overrides[get_speech_transcriber] = FakeSpeechTranscriber
    app.dependency_overrides[get_kinetic_director] = FakeKineticDirector
    try:
        response = client.post(
            "/api/conversations/analyze",
            files={"audio": ("sample.wav", sine_wav(), "audio/wav")},
            data={
                "source_language": "ko-KR",
                "target_language": "ko-KR",
                "conversation_context": "일상",
                "kinetic_mode": "hybrid",
            },
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    payload = response.json()
    assert payload["kinetic_fallback"] is False
    assert payload["kinetic"]["source"] == "google_gemini"
    assert payload["kinetic"]["model"] == "gemini-test"
    assert payload["kinetic"]["segments"][0]["motion"] == "impact"


def test_hybrid_mode_falls_back_when_director_is_unconfigured() -> None:
    app.dependency_overrides[get_speech_transcriber] = FakeSpeechTranscriber
    app.dependency_overrides[get_kinetic_director] = lambda: None
    try:
        response = client.post(
            "/api/conversations/analyze",
            files={"audio": ("sample.wav", sine_wav(), "audio/wav")},
            data={"kinetic_mode": "hybrid"},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["kinetic"] is None
    assert response.json()["kinetic_fallback"] is True
