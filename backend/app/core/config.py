from dataclasses import dataclass, field


@dataclass(frozen=True, slots=True)
class AnalysisConfig:
    """All tunable DSP constants live here instead of in analyzer methods."""

    sample_rate: int = 16_000
    min_duration_seconds: float = 0.25
    max_duration_seconds: float = 90.0
    max_upload_bytes: int = 12 * 1024 * 1024
    silence_rms: float = 1e-4
    frame_seconds: float = 0.025
    hop_seconds: float = 0.010
    pause_min_seconds: float = 0.12
    intonation_window_seconds: float = 0.45
    intonation_change_semitones: float = 0.8
    pitch_floor_hz: float = 60.0
    pitch_ceiling_hz: float = 500.0
    emphasis_weights: dict[str, float] = field(
        default_factory=lambda: {
            "loudness": 0.35,
            "pitch": 0.25,
            "duration": 0.20,
            "energy": 0.20,
        }
    )


DEFAULT_CONFIG = AnalysisConfig()

