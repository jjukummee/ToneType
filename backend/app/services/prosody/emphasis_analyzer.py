from dataclasses import dataclass

import numpy as np

from app.core.config import AnalysisConfig, DEFAULT_CONFIG
from app.schemas.prosody import SegmentProsody, WordTimestamp

from .feature_extractor import FrameFeatures
from .metrics import safe_median, semitone_deviation
from .normalizer import ProsodyNormalizer
from .pitch_analyzer import PitchTrack


@dataclass(frozen=True, slots=True)
class SegmentRawFeatures:
    word: WordTimestamp
    loudness: float
    pitch_hz: float | None
    duration: float


class EmphasisAnalyzer:
    def __init__(
        self,
        config: AnalysisConfig = DEFAULT_CONFIG,
        normalizer: ProsodyNormalizer | None = None,
    ) -> None:
        self.config = config
        self.normalizer = normalizer or ProsodyNormalizer()

    def analyze(
        self,
        words: list[WordTimestamp],
        frames: FrameFeatures,
        pitch: PitchTrack,
        audio_duration: float,
    ) -> list[SegmentProsody]:
        ordered = sorted(words, key=lambda item: item.start)
        raw = [self._features(word, frames, pitch, audio_duration) for word in ordered]
        if not raw:
            return []

        utterance_pitch = safe_median(pitch.hz)
        loudness_scores = self.normalizer.relative([item.loudness for item in raw])
        pitch_deviations = [
            semitone_deviation(item.pitch_hz, utterance_pitch) for item in raw
        ]
        pitch_scores = self.normalizer.relative(pitch_deviations, neutral=0.0)
        duration_scores = self.normalizer.relative([item.duration for item in raw])
        energy_scores = [
            self.normalizer.clamp(0.70 * loudness + 0.30 * pitch_score)
            for loudness, pitch_score in zip(
                loudness_scores, pitch_scores, strict=True
            )
        ]

        weights = self.config.emphasis_weights
        segments: list[SegmentProsody] = []
        for index, item in enumerate(raw):
            emphasis = self.normalizer.clamp(
                weights["loudness"] * loudness_scores[index]
                + weights["pitch"] * pitch_scores[index]
                + weights["duration"] * duration_scores[index]
                + weights["energy"] * energy_scores[index]
            )
            next_start = raw[index + 1].word.start if index + 1 < len(raw) else None
            pause_after = max(0.0, next_start - item.word.end) if next_start else 0.0
            segments.append(
                SegmentProsody(
                    text=item.word.text,
                    start=item.word.start,
                    end=item.word.end,
                    duration=item.duration,
                    relative_loudness=loudness_scores[index],
                    relative_pitch=(
                        pitch_scores[index] if item.pitch_hz is not None else None
                    ),
                    pause_after=pause_after,
                    emphasis=emphasis,
                )
            )
        return segments

    def score(
        self,
        loudness: float,
        pitch: float,
        duration: float,
        energy: float,
    ) -> float:
        weights = self.config.emphasis_weights
        return self.normalizer.clamp(
            weights["loudness"] * loudness
            + weights["pitch"] * pitch
            + weights["duration"] * duration
            + weights["energy"] * energy
        )

    @staticmethod
    def _features(
        word: WordTimestamp,
        frames: FrameFeatures,
        pitch: PitchTrack,
        audio_duration: float,
    ) -> SegmentRawFeatures:
        start = min(max(word.start, 0.0), audio_duration)
        end = min(max(word.end, start), audio_duration)
        frame_mask = (frames.times >= start) & (frames.times <= end)
        pitch_mask = (pitch.times >= start) & (pitch.times <= end)
        loudness = float(np.mean(frames.rms[frame_mask])) if np.any(frame_mask) else 0.0
        pitch_hz = safe_median(pitch.hz[pitch_mask]) if np.any(pitch_mask) else None
        return SegmentRawFeatures(
            word=WordTimestamp(text=word.text, start=start, end=end),
            loudness=loudness,
            pitch_hz=pitch_hz,
            duration=end - start,
        )

