from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.schemas.kinetic import KineticPlanResponse
from app.schemas.prosody import ProsodyResponse, WordTimestamp


class SpeechAnalysisResponse(BaseModel):
    transcript: str = Field(min_length=1)
    detected_language: str
    words: list[WordTimestamp]
    prosody: ProsodyResponse
    kinetic: KineticPlanResponse | None = None
    kinetic_fallback: bool = False


class LiveSpeechStart(BaseModel):
    type: Literal["start"] = "start"
    source_language: str = Field(default="ko-KR", min_length=2, max_length=20)
    target_language: str = Field(default="ko-KR", min_length=2, max_length=20)
    conversation_context: str = Field(default="일상", max_length=40)
    dictionary: list[str] = Field(default_factory=list, max_length=100)

    @field_validator("dictionary")
    @classmethod
    def clean_dictionary(cls, value: list[str]) -> list[str]:
        output: list[str] = []
        for item in value:
            cleaned = item.strip()
            if cleaned and len(cleaned) <= 100 and cleaned not in output:
                output.append(cleaned)
        return output
