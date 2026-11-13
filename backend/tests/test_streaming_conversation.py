import asyncio
from collections.abc import AsyncIterator
from io import BytesIO
import wave

from fastapi.testclient import TestClient

from app.api.routes import conversation as conversation_route
from app.api.routes.conversation import get_streaming_transcriber
from app.main import app
from app.schemas.prosody import WordTimestamp
from app.services.speech import StreamingTranscriptEvent

from .audio_factory import sine_wav


class FakeStreamingTranscriber:
    async def transcribe_stream(
        self,
        audio_chunks: AsyncIterator[bytes],
        *,
        source_language: str,
        target_language: str,
        dictionary: tuple[str, ...] = (),
    ) -> AsyncIterator[StreamingTranscriptEvent]:
        assert source_language == "ko-KR"
        assert target_language == "ko-KR"
        if dictionary:
            assert dictionary == ("ToneType",)
        received = bytearray()
        emitted_interim = False
        async for chunk in audio_chunks:
            received.extend(chunk)
            if not emitted_interim:
                emitted_interim = True
                yield StreamingTranscriptEvent(
                    text="안 되요",
                    committed_text="",
                    detected_language="ko-KR",
                    is_final=False,
                    stability=0.72,
                )
        if not received:
            return
        yield StreamingTranscriptEvent(
            text="안 돼요.",
            committed_text="안 돼요.",
            detected_language="ko-KR",
            is_final=True,
            stability=1.0,
            words=(
                WordTimestamp(text="안", start=0.05, end=0.25),
                WordTimestamp(text="돼요", start=0.3, end=0.72),
            ),
        )


def _pcm_frames() -> bytes:
    with wave.open(BytesIO(sine_wav()), "rb") as wav:
        return wav.readframes(wav.getnframes())


def test_live_stream_emits_partial_and_completes_with_prosody() -> None:
    app.dependency_overrides[get_streaming_transcriber] = FakeStreamingTranscriber
    try:
        with TestClient(app).websocket_connect("/api/conversations/stream") as socket:
            socket.send_json(
                {
                    "type": "start",
                    "source_language": "ko-KR",
                    "target_language": "ko-KR",
                    "conversation_context": "일상",
                    "dictionary": ["ToneType", "ToneType", ""],
                }
            )
            assert socket.receive_json() == {"type": "ready"}
            pcm = _pcm_frames()
            socket.send_bytes(pcm[:12_000])
            interim = socket.receive_json()
            assert interim["type"] == "transcript"
            assert interim["text"] == "안 되요"

            for offset in range(12_000, len(pcm), 12_000):
                socket.send_bytes(pcm[offset : offset + 12_000])
            socket.send_json({"type": "stop"})
            final_transcript = socket.receive_json()
            assert final_transcript["type"] == "transcript"
            assert final_transcript["committed_text"] == "안 돼요."

            completed = socket.receive_json()
            assert completed["type"] == "complete"
            assert completed["transcript"] == "안 돼요."
            assert completed["detected_language"] == "ko-KR"
            assert completed["prosody"]["utterance"]["energy"] > 0
            assert completed["prosody"]["segments"]
    finally:
        app.dependency_overrides.clear()


def test_live_stream_rejects_oversized_audio_chunk() -> None:
    app.dependency_overrides[get_streaming_transcriber] = FakeStreamingTranscriber
    try:
        with TestClient(app).websocket_connect("/api/conversations/stream") as socket:
            socket.send_json({"type": "start"})
            assert socket.receive_json() == {"type": "ready"}
            socket.send_bytes(bytes(15_361))
            error = socket.receive_json()
            assert error["type"] == "error"
            assert error["error"]["code"] == "stream_failed"
    finally:
        app.dependency_overrides.clear()


def test_streaming_client_is_constructed_on_the_asgi_event_loop(monkeypatch) -> None:
    constructed = False

    class LoopAwareStreamingTranscriber:
        def __init__(self) -> None:
            nonlocal constructed
            asyncio.get_running_loop()
            constructed = True

        async def transcribe_stream(
            self,
            audio_chunks: AsyncIterator[bytes],
            **_kwargs,
        ) -> AsyncIterator[StreamingTranscriptEvent]:
            async for _chunk in audio_chunks:
                pass
            if False:
                yield StreamingTranscriptEvent(
                    text="",
                    committed_text="",
                    detected_language="ko-KR",
                    is_final=True,
                )

    app.dependency_overrides.clear()
    monkeypatch.setattr(
        conversation_route,
        "GoogleCloudSpeechStreamingTranscriber",
        LoopAwareStreamingTranscriber,
    )
    conversation_route._streaming_transcriber = None
    try:
        with TestClient(app).websocket_connect("/api/conversations/stream") as socket:
            socket.send_json({"type": "start"})
            assert socket.receive_json() == {"type": "ready"}
            socket.send_json({"type": "stop"})
            assert socket.receive_json()["error"]["code"] == "speech_not_recognized"
        assert constructed is True
    finally:
        conversation_route._streaming_transcriber = None
