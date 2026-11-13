import math

import numpy as np


class ProsodyNormalizer:
    @staticmethod
    def clamp(value: float) -> float:
        if not math.isfinite(value):
            return 0.0
        return float(min(1.0, max(0.0, value)))

    @classmethod
    def linear(cls, value: float, low: float, high: float) -> float:
        if high <= low:
            raise ValueError("high must be greater than low")
        return cls.clamp((value - low) / (high - low))

    @classmethod
    def rms(cls, value: float) -> float:
        decibels = 20 * math.log10(max(value, 1e-9))
        return cls.linear(decibels, -50.0, -12.0)

    @classmethod
    def pitch_hz(cls, value: float) -> float:
        # This is a display normalization, not a high/low speaker judgment.
        return cls.linear(math.log2(max(value, 1.0)), math.log2(70), math.log2(350))

    @classmethod
    def relative(cls, values: list[float], neutral: float = 0.5) -> list[float]:
        if not values:
            return []
        array = np.asarray(values, dtype=float)
        finite = array[np.isfinite(array)]
        if finite.size == 0:
            return [neutral for _ in values]
        low, high = np.percentile(finite, [10, 90])
        median = float(np.median(np.abs(finite)))
        # Do not turn microphone noise or floating-point jitter into extreme
        # 0/1 segment scores. A meaningful within-utterance contrast must exist.
        minimum_contrast = max(median * 0.05, 1e-6)
        if high - low < minimum_contrast:
            return [neutral if math.isfinite(value) else 0.0 for value in values]
        return [
            cls.linear(value, float(low), float(high)) if math.isfinite(value) else 0.0
            for value in values
        ]

    @classmethod
    def speed(cls, words_per_second: float, language: str) -> float:
        language_code = language.lower().split("-")[0]
        ranges = {"ko": (1.5, 4.5), "en": (1.3, 3.8)}
        low, high = ranges.get(language_code, (1.2, 4.0))
        return cls.linear(words_per_second, low, high)
