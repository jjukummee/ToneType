from typing import Protocol

from app.schemas.kinetic import KineticPlanResponse
from app.schemas.prosody import ProsodyResponse


class KineticDirector(Protocol):
    def generate(
        self,
        *,
        transcript: str,
        language: str,
        conversation_context: str,
        prosody: ProsodyResponse,
    ) -> KineticPlanResponse: ...
