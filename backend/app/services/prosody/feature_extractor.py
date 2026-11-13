from dataclasses import dataclass
import logging
import os
from typing import Protocol

import numpy as np

from app.core.config import AnalysisConfig, DEFAULT_CONFIG

from .audio_preprocessor import AudioData

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class FrameFeatures:
    times: np.ndarray
    rms: np.ndarray


class FeatureExtractor(Protocol):
    name: str

    def extract(self, audio: AudioData) -> FrameFeatures: ...


class NumpyFeatureExtractor:
    """License-safe RMS extractor used by default and in tests."""

    name = "numpy"

    def __init__(self, config: AnalysisConfig = DEFAULT_CONFIG) -> None:
        self.config = config

    def extract(self, audio: AudioData) -> FrameFeatures:
        frame_size = max(1, round(audio.sample_rate * self.config.frame_seconds))
        hop_size = max(1, round(audio.sample_rate * self.config.hop_seconds))
        starts = np.arange(0, max(1, len(audio.samples) - frame_size + 1), hop_size)
        if starts.size == 0:
            starts = np.array([0])

        values = np.empty(starts.size, dtype=np.float64)
        for index, start in enumerate(starts):
            frame = audio.samples[start : start + frame_size]
            if frame.size < frame_size:
                frame = np.pad(frame, (0, frame_size - frame.size))
            values[index] = np.sqrt(np.mean(np.square(frame), dtype=np.float64))

        times = (starts + frame_size / 2) / audio.sample_rate
        return FrameFeatures(times=times, rms=values)


class OpenSmileFeatureExtractor:
    """Optional adapter; kept out of the default path due to license constraints."""

    name = "opensmile"

    def __init__(self) -> None:
        try:
            import opensmile
        except ImportError as exc:
            raise RuntimeError("Install the 'opensmile' optional dependency.") from exc
        self._smile = opensmile.Smile(
            feature_set=opensmile.FeatureSet.eGeMAPSv02,
            feature_level=opensmile.FeatureLevel.LowLevelDescriptors,
        )

    def extract(self, audio: AudioData) -> FrameFeatures:
        frame = self._smile.process_signal(audio.samples, audio.sample_rate)
        loudness = frame.filter(like="Loudness").iloc[:, 0].to_numpy(dtype=float)
        times = np.linspace(0, audio.duration, num=len(loudness), endpoint=False)
        # openSMILE loudness is positive but not amplitude RMS. It is scaled to a
        # comparable monotonic range here; normalization remains centralized.
        rms_like = np.maximum(loudness, 0) / max(float(np.max(loudness)), 1e-9)
        return FrameFeatures(times=times, rms=rms_like)


def feature_extractor_from_environment(
    config: AnalysisConfig = DEFAULT_CONFIG,
) -> FeatureExtractor:
    """Select the optional extractor without coupling the domain service to env."""

    requested = os.getenv("PROSODY_FEATURE_EXTRACTOR", "numpy").strip().lower()
    if requested != "opensmile":
        return NumpyFeatureExtractor(config)

    try:
        return OpenSmileFeatureExtractor()
    except RuntimeError as error:
        logger.warning(
            "prosody_opensmile_unavailable",
            extra={"error_type": type(error).__name__},
        )
        return NumpyFeatureExtractor(config)
