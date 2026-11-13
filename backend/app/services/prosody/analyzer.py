import logging
from time import perf_counter

import numpy as np

from app.core.config import AnalysisConfig, DEFAULT_CONFIG
from app.schemas.prosody import (
    ProsodyDebug,
    ProsodyResponse,
    UtteranceProsody,
    WordTimestamp,
)

from .audio_preprocessor import AudioPreprocessor
from .emphasis_analyzer import EmphasisAnalyzer
from .feature_extractor import FeatureExtractor, NumpyFeatureExtractor
from .metrics import (
    classify_intonation,
    frame_pause_ratio,
    pitch_range,
    pitch_variability,
    safe_mean,
    safe_median,
    timestamp_pause_ratio,
    words_per_second,
)
from .normalizer import ProsodyNormalizer
from .pitch_analyzer import PitchAnalyzer, PitchTrack, ResilientPitchAnalyzer

logger = logging.getLogger(__name__)


class ProsodyAnalyzer:
    def __init__(
        self,
        config: AnalysisConfig = DEFAULT_CONFIG,
        feature_extractor: FeatureExtractor | None = None,
        pitch_analyzer: PitchAnalyzer | None = None,
    ) -> None:
        self.config = config
        self.preprocessor = AudioPreprocessor(config)
        self.feature_extractor = feature_extractor or NumpyFeatureExtractor(config)
        self.pitch_analyzer = pitch_analyzer or ResilientPitchAnalyzer(config)
        self.normalizer = ProsodyNormalizer()
        self.emphasis_analyzer = EmphasisAnalyzer(config, self.normalizer)

    def analyze(
        self,
        content: bytes,
        *,
        filename: str | None = None,
        language: str = "ko-KR",
        words: list[WordTimestamp] | None = None,
        debug: bool = False,
    ) -> ProsodyResponse:
        started = perf_counter()
        timings: dict[str, float] = {}
        logger.info("prosody_analysis_started")

        stage = perf_counter()
        audio = self.preprocessor.process(content, filename)
        timings["audio_preprocess"] = _elapsed_ms(stage)

        stage = perf_counter()
        try:
            frames = self.feature_extractor.extract(audio)
        except (RuntimeError, ValueError, IndexError) as error:
            logger.warning(
                "prosody_feature_extractor_failed",
                extra={"error_type": type(error).__name__, "stage": "loudness"},
            )
            frames = NumpyFeatureExtractor(self.config).extract(audio)
        timings["loudness"] = _elapsed_ms(stage)

        stage = perf_counter()
        try:
            pitch = self.pitch_analyzer.analyze(audio)
        except (RuntimeError, ValueError, FloatingPointError) as error:
            logger.warning(
                "prosody_pitch_failed",
                extra={"error_type": type(error).__name__, "stage": "pitch"},
            )
            pitch = PitchTrack(
                times=np.array([], dtype=float),
                hz=np.array([], dtype=float),
                engine="unavailable",
            )
        timings["pitch"] = _elapsed_ms(stage)

        volume = self.normalizer.rms(audio.rms)
        median_pitch = safe_median(pitch.hz)
        pitch_value = (
            self.normalizer.pitch_hz(median_pitch) if median_pitch is not None else None
        )
        energy = self.normalizer.clamp(
            0.70 * volume + 0.30 * pitch_variability(pitch)
        )
        intonation = classify_intonation(pitch, audio.duration, self.config)

        valid_words = self._valid_words(words or [], audio.duration)
        rate = words_per_second(valid_words)
        speed = self.normalizer.speed(rate, language) if rate is not None else None
        pause = timestamp_pause_ratio(valid_words, audio.duration, self.config)
        if pause is None:
            pause = frame_pause_ratio(frames.rms, self.config)

        stage = perf_counter()
        segments = self.emphasis_analyzer.analyze(
            valid_words, frames, pitch, audio.duration
        )
        timings["segments"] = _elapsed_ms(stage)
        timings["total"] = _elapsed_ms(started)

        debug_result = None
        if debug:
            debug_result = ProsodyDebug(
                duration_seconds=audio.duration,
                rms=audio.rms,
                mean_pitch_hz=safe_mean(pitch.hz),
                median_pitch_hz=median_pitch,
                pitch_range_hz=pitch_range(pitch.hz),
                timings_ms=timings,
                pitch_engine=pitch.engine,
            )

        logger.info(
            "prosody_analysis_completed",
            extra={
                "duration_ms": round(timings["total"], 2),
                "audio_seconds": round(audio.duration, 3),
            },
        )
        return ProsodyResponse(
            utterance=UtteranceProsody(
                volume=volume,
                pitch=pitch_value,
                speed=speed,
                energy=energy,
                pause=pause,
                intonation=intonation,
            ),
            segments=segments,
            debug=debug_result,
        )

    @staticmethod
    def _valid_words(
        words: list[WordTimestamp], duration: float
    ) -> list[WordTimestamp]:
        return [
            word
            for word in sorted(words, key=lambda item: item.start)
            if word.start < duration and word.end <= duration + 0.05
        ]


def _elapsed_ms(started: float) -> float:
    return round((perf_counter() - started) * 1000, 3)
