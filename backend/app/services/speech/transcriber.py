from dataclasses import dataclass
from typing import Protocol

from app.schemas.prosody import WordTimestamp


@dataclass(frozen=True, slots=True)
class TranscriptionResult:
    text: str
    language: str
    words: list[WordTimestamp]


class SpeechTranscriber(Protocol):
    def transcribe(
        self,
        content: bytes,
        *,
        language: str,
    ) -> TranscriptionResult: ...
