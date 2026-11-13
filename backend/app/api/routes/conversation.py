import asyncio
import json
import wave
from collections import deque
from collections.abc import AsyncIterator
from functools import lru_cache
from io import BytesIO
from typing import Literal

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, WebSocket
from pydantic import ValidationError
from starlette.websockets import WebSocketDisconnect, WebSocketState
from starlette.concurrency import run_in_threadpool

from app.core.config import DEFAULT_CONFIG
from app.core.errors import ProsodyError
from app.core.google_genai_config import GoogleGenAIConfig
from app.schemas.prosody import ErrorResponse
from app.schemas.prosody import WordTimestamp
from app.schemas.speech import LiveSpeechStart, SpeechAnalysisResponse
from app.services.conversation_audio_analyzer import ConversationAudioAnalyzer
from app.services.kinetic import GoogleGeminiKineticDirector, KineticDirector
from app.services.prosody import ProsodyAnalyzer
from app.services.speech import (
    GoogleCloudSpeechStreamingTranscriber,
    GoogleCloudSpeechTranscriber,
    SpeechTranscriber,
    StreamingSpeechTranscriber,
)
from app.services.speech.text_encoding import restore_utf8_byte_markers

router = APIRouter(prefix="/api/conversations", tags=["conversation"])


@lru_cache(maxsize=1)
def get_speech_transcriber() -> SpeechTranscriber:
    return GoogleCloudSpeechTranscriber()


_streaming_transcriber: StreamingSpeechTranscriber | None = None


async def get_streaming_transcriber() -> StreamingSpeechTranscriber:
    """Create the asyncio gRPC client on the ASGI event-loop thread."""
    global _streaming_transcriber
    if _streaming_transcriber is None:
        _streaming_transcriber = GoogleCloudSpeechStreamingTranscriber()
    return _streaming_transcriber


@lru_cache(maxsize=1)
def get_kinetic_director() -> KineticDirector | None:
    try:
        config = GoogleGenAIConfig.from_environment()
    except ValueError:
        return None
    return GoogleGeminiKineticDirector(config)


@router.post(
    "/analyze",
    response_model=SpeechAnalysisResponse,
    responses={
        400: {"model": ErrorResponse},
        413: {"model": ErrorResponse},
        422: {"model": ErrorResponse},
        503: {"model": ErrorResponse},
    },
)
async def analyze_conversation(
    audio: UploadFile = File(...),
    source_language: str = Form(default="ko-KR", max_length=20),
    target_language: str = Form(default="ko-KR", max_length=20),
    conversation_context: str = Form(default="일상", max_length=40),
    kinetic_mode: Literal["basic", "hybrid"] = Form(default="basic"),
    debug: bool = Query(default=False),
    transcriber: SpeechTranscriber = Depends(get_speech_transcriber),
    kinetic_director: KineticDirector | None = Depends(get_kinetic_director),
) -> SpeechAnalysisResponse:
    content = await audio.read(DEFAULT_CONFIG.max_upload_bytes + 1)
    filename = audio.filename
    await audio.close()
    service = ConversationAudioAnalyzer(
        transcriber,
        kinetic_director=kinetic_director,
    )
    return await run_in_threadpool(
        service.analyze,
        content,
        filename=filename,
        source_language=source_language,
        target_language=target_language,
        conversation_context=conversation_context,
        kinetic_mode=kinetic_mode,
        debug=debug,
    )


@router.websocket("/stream")
async def stream_conversation(
    websocket: WebSocket,
    transcriber: StreamingSpeechTranscriber = Depends(get_streaming_transcriber),
) -> None:
    await websocket.accept()
    try:
        start = LiveSpeechStart.model_validate(await websocket.receive_json())
    except (ValidationError, ValueError, json.JSONDecodeError):
        await _send_error(websocket, "invalid_start", "실시간 번역 설정이 올바르지 않아요.")
        await websocket.close(code=1008)
        return

    audio_queue: asyncio.Queue[bytes | None] = asyncio.Queue(maxsize=32)
    audio = _RollingPcmBuffer()
    transcript = ""
    detected_language = start.source_language
    words: list[WordTimestamp] = []
    disconnected = False

    async def receive_audio() -> None:
        nonlocal disconnected
        try:
            while True:
                message = await websocket.receive()
                if message["type"] == "websocket.disconnect":
                    disconnected = True
                    return
                chunk = message.get("bytes")
                if chunk is not None:
                    if len(chunk) > 15_360:
                        raise ValueError("audio_chunk_too_large")
                    audio.append(chunk)
                    await audio_queue.put(chunk)
                    continue
                text = message.get("text")
                if text:
                    payload = json.loads(text)
                    if payload.get("type") == "stop":
                        return
        except WebSocketDisconnect:
            disconnected = True
        finally:
            await audio_queue.put(None)

    async def chunks() -> AsyncIterator[bytes]:
        while True:
            chunk = await audio_queue.get()
            if chunk is None:
                return
            yield chunk

    async def recognize() -> None:
        nonlocal transcript, detected_language
        async for event in transcriber.transcribe_stream(
            chunks(),
            source_language=start.source_language,
            target_language=start.target_language,
            dictionary=tuple(start.dictionary),
        ):
            display_text = restore_utf8_byte_markers(event.text)
            committed_text = restore_utf8_byte_markers(event.committed_text)
            transcript = committed_text or display_text or transcript
            detected_language = event.detected_language or detected_language
            words.extend(event.words)
            if not disconnected:
                await websocket.send_json(
                    {
                        "type": "transcript",
                        "text": display_text,
                        "committed_text": committed_text,
                        "is_final": event.is_final,
                        "stability": event.stability,
                    }
                )

    await websocket.send_json({"type": "ready"})
    receiver = asyncio.create_task(receive_audio())
    recognition = asyncio.create_task(recognize())
    try:
        done, _ = await asyncio.wait(
            {receiver, recognition}, return_when=asyncio.FIRST_COMPLETED
        )
        if recognition in done and recognition.exception() is not None:
            receiver.cancel()
            await recognition
        await receiver
        await recognition
        if disconnected:
            return
        if not transcript.strip():
            raise ProsodyError(
                "speech_not_recognized", "No recognizable speech was found.", 422
            )
        wav = audio.to_wav()
        recent_words = audio.rebase_words(words)
        prosody = await run_in_threadpool(
            ProsodyAnalyzer().analyze,
            wav,
            filename="live.wav",
            language=start.source_language,
            words=recent_words,
        )
        await websocket.send_json(
            {
                "type": "complete",
                "transcript": transcript.strip(),
                "detected_language": detected_language,
                "prosody": prosody.model_dump(mode="json"),
            }
        )
    except ProsodyError as error:
        if not disconnected:
            await _send_error(websocket, error.code, error.message)
    except (ValueError, json.JSONDecodeError):
        if not disconnected:
            await _send_error(
                websocket,
                "stream_failed",
                "실시간 음성 인식을 계속하지 못했어요.",
            )
    finally:
        for task in (receiver, recognition):
            if not task.done():
                task.cancel()
        await asyncio.gather(receiver, recognition, return_exceptions=True)
        if websocket.client_state == WebSocketState.CONNECTED:
            await websocket.close()


class _RollingPcmBuffer:
    sample_rate = 16_000
    bytes_per_sample = 2
    max_seconds = 90

    def __init__(self) -> None:
        self._chunks: deque[bytes] = deque()
        self._size = 0
        self._dropped = 0

    def append(self, chunk: bytes) -> None:
        self._chunks.append(chunk)
        self._size += len(chunk)
        maximum = self.sample_rate * self.bytes_per_sample * self.max_seconds
        while self._size > maximum and self._chunks:
            removed = self._chunks.popleft()
            self._size -= len(removed)
            self._dropped += len(removed)

    def to_wav(self) -> bytes:
        output = BytesIO()
        with wave.open(output, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(self.bytes_per_sample)
            wav.setframerate(self.sample_rate)
            wav.writeframes(b"".join(self._chunks))
        return output.getvalue()

    def rebase_words(self, words: list[WordTimestamp]) -> list[WordTimestamp]:
        offset = self._dropped / (self.sample_rate * self.bytes_per_sample)
        duration = self._size / (self.sample_rate * self.bytes_per_sample)
        return [
            WordTimestamp(
                text=word.text,
                start=max(0.0, word.start - offset),
                end=word.end - offset,
            )
            for word in words
            if word.end > offset and word.end - offset <= duration + 0.05
        ]


async def _send_error(websocket: WebSocket, code: str, message: str) -> None:
    await websocket.send_json(
        {"type": "error", "error": {"code": code, "message": message}}
    )
