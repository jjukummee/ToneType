import os
import re
from dataclasses import dataclass


_RESOURCE_PATTERN = re.compile(
    r"^projects/(?P<project>[^/]+)/locations/(?P<location>[^/]+)/"
    r"recognizers/(?P<recognizer>[^/]+)$"
)


@dataclass(frozen=True, slots=True)
class GoogleSpeechConfig:
    project_number: str
    location: str
    recognizer_id: str
    model: str = ""
    explicit_resource: str | None = None

    @classmethod
    def from_environment(cls) -> "GoogleSpeechConfig":
        explicit = os.getenv("GOOGLE_SPEECH_RECOGNIZER", "").strip()
        model = os.getenv("GOOGLE_SPEECH_MODEL", "").strip()
        if explicit:
            match = _RESOURCE_PATTERN.fullmatch(explicit)
            if match is None:
                raise ValueError("GOOGLE_SPEECH_RECOGNIZER is invalid")
            return cls(
                project_number=match.group("project"),
                location=match.group("location"),
                recognizer_id=match.group("recognizer"),
                model=model,
                explicit_resource=explicit,
            )

        project_number = os.getenv("GOOGLE_CLOUD_PROJECT_NUMBER", "").strip()
        location = os.getenv("GOOGLE_CLOUD_LOCATION", "").strip()
        recognizer_id = os.getenv("GOOGLE_SPEECH_RECOGNIZER_ID", "").strip()
        if not project_number or not location or not recognizer_id:
            raise ValueError("Google Speech recognizer configuration is missing")
        return cls(
            project_number=project_number,
            location=location,
            recognizer_id=recognizer_id,
            model=model,
        )

    @property
    def recognizer_resource(self) -> str:
        if self.explicit_resource:
            return self.explicit_resource
        return (
            f"projects/{self.project_number}/locations/{self.location}/"
            f"recognizers/{self.recognizer_id}"
        )

    @property
    def api_endpoint(self) -> str:
        return f"{self.location}-speech.googleapis.com"
