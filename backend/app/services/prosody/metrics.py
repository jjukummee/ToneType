import math

import numpy as np

from app.core.config import AnalysisConfig, DEFAULT_CONFIG
from app.schemas.prosody import WordTimestamp

from .pitch_analyzer import PitchTrack


def classify_intonation(
    track: PitchTrack,
    duration: float,
    config: AnalysisConfig = DEFAULT_CONFIG,
) -> str:
    valid = np.isfinite(track.hz) & (track.hz > 0)
    valid &= track.times >= max(0.0, duration - config.intonation_window_seconds)
    times = track.times[valid]
    pitches = track.hz[valid]
    if pitches.size < 3 or times[-1] - times[0] < 0.08:
        return "unknown"

    semitones = 12 * np.log2(pitches / np.median(pitches))
    slope = float(np.polyfit(times - times[0], semitones, 1)[0])
    change = slope * float(times[-1] - times[0])
    if change >= config.intonation_change_semitones:
        return "rising"
    if change <= -config.intonation_change_semitones:
        return "falling"
    return "flat"


def words_per_second(words: list[WordTimestamp]) -> float | None:
    if not words:
        return None
    start = min(word.start for word in words)
    end = max(word.end for word in words)
    active_duration = end - start
    if active_duration <= 0:
        return None
    return len(words) / active_duration


def timestamp_pause_ratio(
    words: list[WordTimestamp],
    duration: float,
    config: AnalysisConfig = DEFAULT_CONFIG,
) -> float | None:
    if len(words) < 2 or duration <= 0:
        return None
    ordered = sorted(words, key=lambda item: item.start)
    pause = sum(
        max(0.0, current.start - previous.end)
        for previous, current in zip(ordered, ordered[1:], strict=False)
        if current.start - previous.end >= config.pause_min_seconds
    )
    return min(1.0, pause / duration / 0.4)


def frame_pause_ratio(
    rms: np.ndarray,
    config: AnalysisConfig = DEFAULT_CONFIG,
) -> float:
    if rms.size == 0:
        return 0.0
    threshold = max(config.silence_rms * 2, float(np.max(rms)) * 0.12)
    active = np.flatnonzero(rms >= threshold)
    if active.size < 2:
        return 0.0
    internal = rms[active[0] : active[-1] + 1]
    pause_fraction = float(np.mean(internal < threshold))
    return min(1.0, pause_fraction / 0.4)


def pitch_variability(track: PitchTrack) -> float:
    voiced = track.voiced_hz
    if voiced.size < 2:
        return 0.0
    semitones = 12 * np.log2(voiced / np.median(voiced))
    return min(1.0, float(np.std(semitones)) / 4.0)


def safe_median(values: np.ndarray) -> float | None:
    finite = values[np.isfinite(values) & (values > 0)]
    return float(np.median(finite)) if finite.size else None


def safe_mean(values: np.ndarray) -> float | None:
    finite = values[np.isfinite(values) & (values > 0)]
    return float(np.mean(finite)) if finite.size else None


def pitch_range(values: np.ndarray) -> float | None:
    finite = values[np.isfinite(values) & (values > 0)]
    if finite.size < 2:
        return None
    return float(np.percentile(finite, 95) - np.percentile(finite, 5))


def semitone_deviation(value: float | None, baseline: float | None) -> float:
    if value is None or baseline is None or value <= 0 or baseline <= 0:
        return math.nan
    return abs(12 * math.log2(value / baseline))

