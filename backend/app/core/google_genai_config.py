import os
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class GoogleGenAIConfig:
    project_id: str | None
    api_key: str | None
    location: str = "global"
    model: str = "gemini-2.5-flash"

    @classmethod
    def from_environment(cls) -> "GoogleGenAIConfig":
        api_key = os.getenv("GOOGLE_GENAI_API_KEY", "").strip() or None
        project_id = (
            os.getenv("GOOGLE_GENAI_PROJECT", "").strip()
            or os.getenv("GOOGLE_CLOUD_PROJECT", "").strip()
            or None
        )
        if not api_key and not project_id:
            raise ValueError(
                "GOOGLE_GENAI_API_KEY or a Google Cloud project is required"
            )
        location = os.getenv("GOOGLE_GENAI_LOCATION", "global").strip() or "global"
        model = os.getenv("GOOGLE_GENAI_MODEL", "gemini-2.5-flash").strip()
        if not model:
            raise ValueError("GOOGLE_GENAI_MODEL is required")
        return cls(
            project_id=project_id,
            api_key=api_key,
            location=location,
            model=model,
        )
