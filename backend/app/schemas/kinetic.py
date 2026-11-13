from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

KineticMotion = Literal[
    "neutral",
    "impact",
    "soft",
    "whisper",
    "rise",
    "settle",
    "stagger",
    "rapid",
    "stretch",
]
KineticIntensity = Literal["subtle", "medium", "strong"]


class GeminiKineticDirective(BaseModel):
    model_config = ConfigDict(extra="forbid")

    word_index: int = Field(ge=0)
    motion: KineticMotion
    intensity: KineticIntensity


class GeminiKineticDirections(BaseModel):
    model_config = ConfigDict(extra="forbid")

    interpretation: str = Field(min_length=1, max_length=120)
    directives: list[GeminiKineticDirective] = Field(max_length=80)


class KineticSegmentResponse(BaseModel):
    text: str = Field(min_length=1)
    motion: KineticMotion
    intensity: KineticIntensity


class KineticPlanResponse(BaseModel):
    source: Literal["google_gemini"] = "google_gemini"
    model: str
    interpretation: str
    segments: list[KineticSegmentResponse] = Field(min_length=1)
