from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Protocol

from app.schemas.prosody import WordTimestamp


@dataclass(frozen=True, slots=True)
class StreamingTranscriptEvent:
    text: str
    committed_text: str
    detected_language: str
    is_final: bool
    stability: float = 0.0
    words: tuple[WordTimestamp, ...] = ()


class StreamingSpeechTranscriber(Protocol):
    async def transcribe_stream(
        self,
        audio_chunks: AsyncIterator[bytes],
        *,
        source_language: str,
        target_language: str,
        dictionary: tuple[str, ...] = (),
    ) -> AsyncIterator[StreamingTranscriptEvent]: ...
