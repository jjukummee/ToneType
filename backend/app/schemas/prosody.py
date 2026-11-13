from typing import Literal

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, model_validator


class WordTimestamp(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: str = Field(
        min_length=1,
        max_length=200,
        validation_alias=AliasChoices("text", "word"),
    )
    start: float = Field(ge=0)
    end: float = Field(gt=0)

    @model_validator(mode="after")
    def validate_range(self) -> "WordTimestamp":
        if self.end <= self.start:
            raise ValueError("end must be greater than start")
        return self


class UtteranceProsody(BaseModel):
    volume: float = Field(ge=0, le=1)
    pitch: float | None = Field(default=None, ge=0, le=1)
    speed: float | None = Field(default=None, ge=0, le=1)
    energy: float = Field(ge=0, le=1)
    pause: float = Field(ge=0, le=1)
    intonation: Literal["rising", "flat", "falling", "unknown"]


class SegmentProsody(BaseModel):
    text: str
    start: float = Field(ge=0)
    end: float = Field(gt=0)
    duration: float = Field(gt=0)
    relative_loudness: float = Field(ge=0, le=1)
    relative_pitch: float | None = Field(default=None, ge=0, le=1)
    pause_after: float = Field(ge=0)
    emphasis: float = Field(ge=0, le=1)


class ProsodyDebug(BaseModel):
    duration_seconds: float
    rms: float
    mean_pitch_hz: float | None = None
    median_pitch_hz: float | None = None
    pitch_range_hz: float | None = None
    timings_ms: dict[str, float]
    pitch_engine: str


class ProsodyResponse(BaseModel):
    utterance: UtteranceProsody
    segments: list[SegmentProsody]
    debug: ProsodyDebug | None = None


class ErrorDetail(BaseModel):
    code: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorDetail
