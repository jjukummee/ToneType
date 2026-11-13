import logging
from datetime import timedelta
from typing import Any

from google.api_core.client_options import ClientOptions
from google.api_core.exceptions import GoogleAPICallError
from google.auth.exceptions import DefaultCredentialsError
from google.cloud import speech_v2 as speech

from app.core.errors import ProsodyError
from app.core.google_speech_config import (
    GoogleSpeechConfig,
)
from app.schemas.prosody import WordTimestamp

from .transcriber import TranscriptionResult
from .text_encoding import restore_utf8_byte_markers

logger = logging.getLogger(__name__)


class GoogleCloudSpeechTranscriber:
    """Google STT V2 adapter. Credentials are resolved server-side with ADC."""

    def __init__(
        self,
        config: GoogleSpeechConfig | None = None,
        client: speech.SpeechClient | None = None,
    ) -> None:
        try:
            self.config = config or GoogleSpeechConfig.from_environment()
        except ValueError as error:
            raise ProsodyError(
                "speech_configuration_missing",
                "Google Speech recognizer configuration is missing on the server.",
                503,
            ) from error
        try:
            self.client = client or speech.SpeechClient(
                client_options=ClientOptions(api_endpoint=self.config.api_endpoint)
            )
        except DefaultCredentialsError as error:
            raise ProsodyError(
                "speech_credentials_missing",
                "Google Speech credentials are not configured on the server.",
                503,
            ) from error

    def transcribe(self, content: bytes, *, language: str) -> TranscriptionResult:
        normalized_language = language.replace("_", "-")
        recognition_config = speech.RecognitionConfig(
            auto_decoding_config=speech.AutoDetectDecodingConfig(),
            language_codes=[normalized_language],
            features=speech.RecognitionFeatures(
                enable_automatic_punctuation=True,
                enable_word_time_offsets=True,
            ),
        )
        if self.config.model:
            recognition_config.model = self.config.model

        request = speech.RecognizeRequest(
            recognizer=self.config.recognizer_resource,
            config=recognition_config,
            content=content,
        )
        try:
            response = self.client.recognize(request=request, timeout=20)
        except GoogleAPICallError as error:
            logger.warning(
                "google_speech_request_failed",
                extra={"error_type": type(error).__name__},
            )
            raise ProsodyError(
                "speech_service_unavailable",
                "Google Speech could not transcribe this audio.",
                503,
            ) from error

        text_parts: list[str] = []
        words: list[WordTimestamp] = []
        detected_language = normalized_language
        for result in response.results:
            if not result.alternatives:
                continue
            alternative = result.alternatives[0]
            restored_text = restore_utf8_byte_markers(
                alternative.transcript
            ).strip()
            if restored_text:
                text_parts.append(restored_text)
            detected_language = result.language_code or detected_language
            for word in alternative.words:
                start = _duration_seconds(word.start_offset)
                end = _duration_seconds(word.end_offset)
                restored_word = restore_utf8_byte_markers(word.word).strip()
                if restored_word and end > start:
                    words.append(
                        WordTimestamp(
                            text=restored_word,
                            start=start,
                            end=end,
                        )
                    )

        transcript = " ".join(text_parts).strip()
        if not transcript:
            raise ProsodyError(
                "speech_not_recognized",
                "No recognizable speech was found in the audio.",
                422,
            )
        return TranscriptionResult(
            text=transcript,
            language=detected_language,
            words=words,
        )


def _duration_seconds(value: Any) -> float:
    if isinstance(value, timedelta):
        return value.total_seconds()
    seconds = float(getattr(value, "seconds", 0))
    nanos = float(getattr(value, "nanos", 0))
    return seconds + nanos / 1_000_000_000
