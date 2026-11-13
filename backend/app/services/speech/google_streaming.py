import logging
from collections.abc import AsyncIterator
from typing import Any

from google.api_core.client_options import ClientOptions
from google.api_core.exceptions import GoogleAPICallError
from google.auth.exceptions import DefaultCredentialsError
from google.cloud import speech_v2 as speech

from app.core.errors import ProsodyError
from app.core.google_speech_config import GoogleSpeechConfig
from app.schemas.prosody import WordTimestamp

from .streaming import StreamingTranscriptEvent
from .text_encoding import restore_utf8_byte_markers

logger = logging.getLogger(__name__)

_SAMPLE_RATE = 16_000
_BYTES_PER_SECOND = _SAMPLE_RATE * 2
_MAX_STREAM_SECONDS = 285


class GoogleCloudSpeechStreamingTranscriber:
    """Google STT V2 bidirectional streaming adapter using server-side ADC."""

    def __init__(
        self,
        config: GoogleSpeechConfig | None = None,
        client: speech.SpeechAsyncClient | None = None,
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
            self.client = client or speech.SpeechAsyncClient(
                client_options=ClientOptions(api_endpoint=self.config.api_endpoint)
            )
        except DefaultCredentialsError as error:
            raise ProsodyError(
                "speech_credentials_missing",
                "Google Speech credentials are not configured on the server.",
                503,
            ) from error

    async def transcribe_stream(
        self,
        audio_chunks: AsyncIterator[bytes],
        *,
        source_language: str,
        target_language: str,
        dictionary: tuple[str, ...] = (),
    ) -> AsyncIterator[StreamingTranscriptEvent]:
        source = source_language.replace("_", "-")
        target = target_language.replace("_", "-")
        iterator = audio_chunks.__aiter__()
        committed_parts: list[str] = []
        stream_offset = 0.0
        source_exhausted = False

        while not source_exhausted:
            bytes_sent = 0

            async def requests() -> AsyncIterator[speech.StreamingRecognizeRequest]:
                nonlocal bytes_sent, source_exhausted
                yield self._config_request(source, target, dictionary)
                maximum = _MAX_STREAM_SECONDS * _BYTES_PER_SECOND
                while bytes_sent < maximum:
                    try:
                        chunk = await iterator.__anext__()
                    except StopAsyncIteration:
                        source_exhausted = True
                        return
                    if not chunk:
                        continue
                    bytes_sent += len(chunk)
                    yield speech.StreamingRecognizeRequest(audio=chunk)

            try:
                responses = await self.client.streaming_recognize(requests=requests())
                async for response in responses:
                    interim_parts: list[str] = []
                    new_words: list[WordTimestamp] = []
                    has_final = False
                    detected = source
                    stability = 0.0
                    for result in response.results:
                        if not result.alternatives:
                            continue
                        alternative = result.alternatives[0]
                        text = restore_utf8_byte_markers(
                            alternative.transcript
                        ).strip()
                        detected = result.language_code or detected
                        if result.is_final:
                            has_final = True
                            if text:
                                committed_parts.append(text)
                            for word in alternative.words:
                                start = stream_offset + _duration_seconds(
                                    word.start_offset
                                )
                                end = stream_offset + _duration_seconds(word.end_offset)
                                restored_word = restore_utf8_byte_markers(
                                    word.word
                                ).strip()
                                if restored_word and end > start:
                                    new_words.append(
                                        WordTimestamp(
                                            text=restored_word,
                                            start=start,
                                            end=end,
                                        )
                                    )
                        elif text:
                            interim_parts.append(text)
                            stability = max(stability, float(result.stability))

                    committed = _join_text(committed_parts)
                    display = _join_text([committed, *interim_parts])
                    if display or has_final:
                        yield StreamingTranscriptEvent(
                            text=display,
                            committed_text=committed,
                            detected_language=detected,
                            is_final=has_final and not interim_parts,
                            stability=max(0.0, min(1.0, stability)),
                            words=tuple(new_words),
                        )
            except GoogleAPICallError as error:
                logger.warning(
                    "google_speech_stream_failed",
                    extra={"error_type": type(error).__name__},
                )
                raise ProsodyError(
                    "speech_service_unavailable",
                    "Google Speech streaming recognition is unavailable.",
                    503,
                ) from error

            stream_offset += bytes_sent / _BYTES_PER_SECOND

    def _config_request(
        self,
        source: str,
        target: str,
        dictionary: tuple[str, ...],
    ) -> speech.StreamingRecognizeRequest:
        phrases = [
            speech.PhraseSet.Phrase(value=word, boost=8.0)
            for word in dictionary[:100]
            if word.strip()
        ]
        adaptation = None
        if phrases:
            adaptation = speech.SpeechAdaptation(
                phrase_sets=[
                    speech.SpeechAdaptation.AdaptationPhraseSet(
                        inline_phrase_set=speech.PhraseSet(phrases=phrases)
                    )
                ]
            )
        recognition_config = speech.RecognitionConfig(
            explicit_decoding_config=speech.ExplicitDecodingConfig(
                encoding=speech.ExplicitDecodingConfig.AudioEncoding.LINEAR16,
                sample_rate_hertz=_SAMPLE_RATE,
                audio_channel_count=1,
            ),
            language_codes=[source],
            features=speech.RecognitionFeatures(
                enable_automatic_punctuation=True,
                enable_word_time_offsets=True,
            ),
        )
        if adaptation is not None:
            recognition_config.adaptation = adaptation
        if self.config.model:
            recognition_config.model = self.config.model
        if source.split("-")[0] != target.split("-")[0]:
            recognition_config.translation_config = speech.TranslationConfig(
                target_language=target
            )
        streaming_config = speech.StreamingRecognitionConfig(
            config=recognition_config,
            streaming_features=speech.StreamingRecognitionFeatures(
                interim_results=True,
                enable_voice_activity_events=True,
            ),
        )
        return speech.StreamingRecognizeRequest(
            recognizer=self.config.recognizer_resource,
            streaming_config=streaming_config,
        )


def _join_text(parts: list[str]) -> str:
    return " ".join(part.strip() for part in parts if part.strip()).strip()


def _duration_seconds(value: Any) -> float:
    seconds = float(getattr(value, "seconds", 0))
    nanos = float(getattr(value, "nanos", 0))
    return seconds + nanos / 1_000_000_000
