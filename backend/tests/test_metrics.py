import numpy as np
import pytest

from app.schemas.prosody import WordTimestamp
from app.services.prosody.emphasis_analyzer import EmphasisAnalyzer
from app.services.prosody.metrics import classify_intonation, words_per_second
from app.services.prosody.normalizer import ProsodyNormalizer
from app.services.prosody.pitch_analyzer import PitchTrack


def test_normalizer_clamps_and_handles_constant_relative_values() -> None:
    normalizer = ProsodyNormalizer()
    assert normalizer.linear(-10, 0, 1) == 0
    assert normalizer.linear(10, 0, 1) == 1
    assert normalizer.relative([3, 3, 3]) == [0.5, 0.5, 0.5]
    assert normalizer.relative([0.200, 0.202]) == [0.5, 0.5]


def test_emphasis_uses_configured_weighted_score() -> None:
    score = EmphasisAnalyzer().score(
        loudness=1.0,
        pitch=0.8,
        duration=0.6,
        energy=0.9,
    )
    assert score == pytest.approx(0.85)


def test_intonation_uses_a_stable_final_window() -> None:
    times = np.linspace(0.6, 1.0, 9)
    rising = PitchTrack(times=times, hz=np.linspace(150, 190, 9), engine="test")
    falling = PitchTrack(times=times, hz=np.linspace(190, 150, 9), engine="test")
    flat = PitchTrack(times=times, hz=np.full(9, 170.0), engine="test")

    assert classify_intonation(rising, 1.0) == "rising"
    assert classify_intonation(falling, 1.0) == "falling"
    assert classify_intonation(flat, 1.0) == "flat"


def test_speech_rate_uses_timestamp_span() -> None:
    words = [
        WordTimestamp(text="one", start=0.0, end=0.2),
        WordTimestamp(text="two", start=0.3, end=0.5),
        WordTimestamp(text="three", start=0.6, end=1.0),
    ]
    assert words_per_second(words) == 3.0
