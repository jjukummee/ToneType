"""A live session keeps up to 90 seconds of audio, so the analyser and the
rolling buffer must agree on that limit. If they drift apart the final pass
fails with `audio_too_long` and the speaker loses their prosody entirely.
"""

import time

import pytest

from app.api.routes.conversation import _RollingPcmBuffer
from app.core.config import DEFAULT_CONFIG
from app.core.errors import ProsodyError
from app.schemas.prosody import WordTimestamp
from app.services.prosody import ProsodyAnalyzer

from .audio_factory import sine_wav


def test_rolling_buffer_and_analyser_agree_on_the_limit() -> None:
    assert _RollingPcmBuffer.max_seconds <= DEFAULT_CONFIG.max_duration_seconds


def test_audio_longer_than_thirty_seconds_is_analysed() -> None:
    content = sine_wav(duration=75.0)
    words = []
    cursor = 0.0
    while cursor + 0.36 < 75.0:
        words.append(WordTimestamp(text="단어", start=cursor, end=cursor + 0.32))
        cursor += 0.36

    started = time.perf_counter()
    result = ProsodyAnalyzer().analyze(
        content, filename="live.wav", language="ko-KR", words=words
    )
    elapsed = time.perf_counter() - started

    assert len(result.segments) == len(words)
    # The app gives the final pass 25 seconds before it gives up.
    assert elapsed < 10.0


def test_audio_beyond_the_limit_is_still_rejected() -> None:
    with pytest.raises(ProsodyError) as error:
        ProsodyAnalyzer().analyze(
            sine_wav(duration=DEFAULT_CONFIG.max_duration_seconds + 2),
            filename="live.wav",
            language="ko-KR",
        )
    assert error.value.code == "audio_too_long"


def test_rolling_buffer_retains_ninety_seconds_of_pcm() -> None:
    buffer = _RollingPcmBuffer()
    chunk = b"\x00\x01" * 1600  # 0.1 s of 16 kHz mono PCM
    for _ in range(1500):  # 150 s of audio, well past the limit
        buffer.append(chunk)

    retained = len(buffer.to_wav()) - 44  # minus the WAV header
    seconds = retained / (_RollingPcmBuffer.sample_rate * _RollingPcmBuffer.bytes_per_sample)
    assert seconds == pytest.approx(_RollingPcmBuffer.max_seconds, abs=1.0)
