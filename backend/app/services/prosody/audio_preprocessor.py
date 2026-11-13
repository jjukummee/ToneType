from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

from app.core.config import AnalysisConfig, DEFAULT_CONFIG
from app.core.errors import ProsodyError


@dataclass(frozen=True, slots=True)
class AudioData:
    samples: np.ndarray
    sample_rate: int

    @property
    def duration(self) -> float:
        return float(len(self.samples) / self.sample_rate)

    @property
    def rms(self) -> float:
        return float(np.sqrt(np.mean(np.square(self.samples), dtype=np.float64)))


class AudioPreprocessor:
    """Decode, validate, downmix and resample untrusted upload bytes."""

    supported_suffixes = {".wav", ".flac", ".ogg", ".mp3", ".m4a"}

    def __init__(self, config: AnalysisConfig = DEFAULT_CONFIG) -> None:
        self.config = config

    def process(self, content: bytes, filename: str | None = None) -> AudioData:
        if not content:
            raise ProsodyError("empty_audio", "The uploaded audio file is empty.", 400)
        if len(content) > self.config.max_upload_bytes:
            raise ProsodyError("audio_too_large", "The audio file exceeds 12 MB.", 413)

        suffix = Path(filename or "audio.wav").suffix.lower()
        if suffix and suffix not in self.supported_suffixes:
            raise ProsodyError(
                "unsupported_format",
                "Use WAV, FLAC, OGG, MP3, or M4A audio.",
                415,
            )

        try:
            samples, sample_rate = sf.read(
                BytesIO(content), dtype="float32", always_2d=True
            )
        except (RuntimeError, ValueError) as exc:
            message = (
                "Audio could not be decoded. WAV is always supported; MP3/M4A "
                "requires a libsndfile build with the matching codec."
            )
            raise ProsodyError("invalid_audio", message, 422) from exc

        if samples.size == 0 or sample_rate <= 0:
            raise ProsodyError("empty_audio", "Decoded audio contains no samples.", 400)

        mono = np.mean(samples, axis=1, dtype=np.float32)
        if sample_rate != self.config.sample_rate:
            divisor = int(np.gcd(sample_rate, self.config.sample_rate))
            mono = resample_poly(
                mono,
                self.config.sample_rate // divisor,
                sample_rate // divisor,
            ).astype(np.float32)
            sample_rate = self.config.sample_rate

        mono = np.nan_to_num(mono, nan=0.0, posinf=0.0, neginf=0.0)
        peak = float(np.max(np.abs(mono))) if mono.size else 0.0
        if peak > 1.0:
            mono = mono / peak

        audio = AudioData(samples=mono, sample_rate=sample_rate)
        if audio.duration < self.config.min_duration_seconds:
            raise ProsodyError("audio_too_short", "Audio must be at least 250 ms.")
        if audio.duration > self.config.max_duration_seconds:
            raise ProsodyError("audio_too_long", "Audio must be 90 seconds or shorter.")
        if audio.rms < self.config.silence_rms:
            raise ProsodyError("silence_only", "No audible speech was detected.")
        return audio

