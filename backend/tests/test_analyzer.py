import pytest

from app.core.errors import ProsodyError
from app.schemas.prosody import WordTimestamp
from app.services.prosody import ProsodyAnalyzer
from app.services.prosody.feature_extractor import (
    NumpyFeatureExtractor,
    feature_extractor_from_environment,
)

from .audio_factory import sine_wav


def test_utterance_analysis_works_without_stt() -> None:
    result = ProsodyAnalyzer().analyze(
        sine_wav(), filename="tone.wav", debug=True
    )

    assert 0 <= result.utterance.volume <= 1
    assert result.utterance.pitch is not None
    assert 0 <= result.utterance.energy <= 1
    assert result.utterance.speed is None
    assert result.segments == []
    assert result.debug is not None
    assert result.debug.median_pitch_hz == pytest.approx(180, rel=0.08)


def test_timestamps_enable_segment_and_emphasis_analysis() -> None:
    words = [
        WordTimestamp(text="내일", start=0.0, end=0.25),
        WordTimestamp(text="말고", start=0.30, end=0.50),
        WordTimestamp(text="오늘", start=0.56, end=0.90),
    ]
    result = ProsodyAnalyzer().analyze(
        sine_wav(), filename="tone.wav", words=words
    )

    assert len(result.segments) == 3
    assert result.utterance.speed is not None
    assert result.segments[1].pause_after == pytest.approx(0.06)
    assert all(0 <= segment.emphasis <= 1 for segment in result.segments)


@pytest.mark.parametrize(
    ("content", "code"),
    [(b"", "empty_audio"), (b"not audio", "invalid_audio")],
)
def test_invalid_audio_is_rejected(content: bytes, code: str) -> None:
    with pytest.raises(ProsodyError) as error:
        ProsodyAnalyzer().analyze(content, filename="bad.wav")
    assert error.value.code == code


def test_silence_only_audio_is_rejected() -> None:
    with pytest.raises(ProsodyError) as error:
        ProsodyAnalyzer().analyze(
            sine_wav(amplitude=0), filename="silence.wav"
        )
    assert error.value.code == "silence_only"


def test_feature_extractor_defaults_to_license_safe_numpy(monkeypatch) -> None:
    monkeypatch.delenv("PROSODY_FEATURE_EXTRACTOR", raising=False)
    assert isinstance(feature_extractor_from_environment(), NumpyFeatureExtractor)
