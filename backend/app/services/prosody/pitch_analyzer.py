from dataclasses import dataclass
from typing import Protocol

import numpy as np

from app.core.config import AnalysisConfig, DEFAULT_CONFIG

from .audio_preprocessor import AudioData


@dataclass(frozen=True, slots=True)
class PitchTrack:
    times: np.ndarray
    hz: np.ndarray
    engine: str

    @property
    def voiced_hz(self) -> np.ndarray:
        return self.hz[np.isfinite(self.hz) & (self.hz > 0)]


class PitchAnalyzer(Protocol):
    def analyze(self, audio: AudioData) -> PitchTrack: ...


class ParselmouthPitchAnalyzer:
    def __init__(self, config: AnalysisConfig = DEFAULT_CONFIG) -> None:
        self.config = config

    def analyze(self, audio: AudioData) -> PitchTrack:
        try:
            import parselmouth
        except ImportError as exc:
            raise RuntimeError("praat-parselmouth is not installed") from exc

        sound = parselmouth.Sound(audio.samples, sampling_frequency=audio.sample_rate)
        pitch = sound.to_pitch_ac(
            time_step=self.config.hop_seconds,
            pitch_floor=self.config.pitch_floor_hz,
            pitch_ceiling=self.config.pitch_ceiling_hz,
        )
        hz = pitch.selected_array["frequency"].astype(float)
        hz[hz <= 0] = np.nan
        times = pitch.xs().astype(float)
        return PitchTrack(times=times, hz=hz, engine="parselmouth")


class AutocorrelationPitchAnalyzer:
    """Dependency-light fallback suitable for MVP and deterministic tests."""

    def __init__(self, config: AnalysisConfig = DEFAULT_CONFIG) -> None:
        self.config = config

    def analyze(self, audio: AudioData) -> PitchTrack:
        frame_size = round(audio.sample_rate * 0.040)
        hop_size = round(audio.sample_rate * self.config.hop_seconds)
        min_lag = max(1, int(audio.sample_rate / self.config.pitch_ceiling_hz))
        max_lag = min(frame_size - 2, int(audio.sample_rate / self.config.pitch_floor_hz))
        starts = np.arange(0, max(1, len(audio.samples) - frame_size + 1), hop_size)
        values = np.full(starts.size, np.nan, dtype=float)
        window = np.hanning(frame_size)

        for index, start in enumerate(starts):
            frame = audio.samples[start : start + frame_size]
            if frame.size < frame_size:
                frame = np.pad(frame, (0, frame_size - frame.size))
            frame = (frame - np.mean(frame)) * window
            power = float(np.dot(frame, frame))
            if power < 1e-7:
                continue
            correlation = np.correlate(frame, frame, mode="full")[frame_size - 1 :]
            region = correlation[min_lag : max_lag + 1]
            lag_offset = int(np.argmax(region))
            lag = lag_offset + min_lag
            if correlation[lag] / max(correlation[0], 1e-9) < 0.25:
                continue
            values[index] = audio.sample_rate / lag

        times = (starts + frame_size / 2) / audio.sample_rate
        return PitchTrack(times=times, hz=values, engine="autocorrelation")


class ResilientPitchAnalyzer:
    """Prefer Praat while keeping the service operational without it."""

    def __init__(self, config: AnalysisConfig = DEFAULT_CONFIG) -> None:
        self._primary = ParselmouthPitchAnalyzer(config)
        self._fallback = AutocorrelationPitchAnalyzer(config)

    def analyze(self, audio: AudioData) -> PitchTrack:
        try:
            return self._primary.analyze(audio)
        except (RuntimeError, ValueError):
            return self._fallback.analyze(audio)

