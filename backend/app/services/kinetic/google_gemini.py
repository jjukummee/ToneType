import json
import logging

from google import genai
from google.genai import types

from app.core.google_genai_config import GoogleGenAIConfig
from app.schemas.kinetic import (
    GeminiKineticDirections,
    KineticPlanResponse,
    KineticSegmentResponse,
)
from app.schemas.prosody import ProsodyResponse, SegmentProsody

logger = logging.getLogger(__name__)

_SYSTEM_INSTRUCTION = """You are ToneType's kinetic typography director.
Use semantics and conversation context to complement, never replace, measured audio
prosody. Return concise directions indexed to the supplied word list. Preserve the
speaker's meaning. Strong visual intensity should be rare. Do not invent words,
translation, emotion, or acoustic measurements. Use only the provided indexes."""


class GoogleGeminiKineticDirector:
    def __init__(
        self,
        config: GoogleGenAIConfig,
        client: genai.Client | None = None,
    ) -> None:
        self.config = config
        if client is not None:
            self.client = client
        elif config.api_key:
            self.client = genai.Client(api_key=config.api_key)
        else:
            self.client = genai.Client(
                vertexai=True,
                project=config.project_id,
                location=config.location,
                http_options=types.HttpOptions(api_version="v1"),
            )

    def generate(
        self,
        *,
        transcript: str,
        language: str,
        conversation_context: str,
        prosody: ProsodyResponse,
    ) -> KineticPlanResponse:
        prompt = json.dumps(
            {
                "task": "Direct kinetic typography for this spoken sentence.",
                "transcript": transcript,
                "language": language,
                "conversation_context": conversation_context,
                "utterance_prosody": prosody.utterance.model_dump(),
                "words": [
                    {
                        "index": index,
                        "text": segment.text,
                        "emphasis": segment.emphasis,
                        "relative_loudness": segment.relative_loudness,
                        "relative_pitch": segment.relative_pitch,
                        "pause_after": segment.pause_after,
                    }
                    for index, segment in enumerate(prosody.segments)
                ],
            },
            ensure_ascii=False,
        )
        response = self.client.models.generate_content(
            model=self.config.model,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=_SYSTEM_INSTRUCTION,
                response_mime_type="application/json",
                response_schema=GeminiKineticDirections,
                temperature=0.2,
                max_output_tokens=1200,
            ),
        )
        parsed = response.parsed
        if isinstance(parsed, GeminiKineticDirections):
            directions = parsed
        elif parsed is not None:
            directions = GeminiKineticDirections.model_validate(parsed)
        else:
            directions = GeminiKineticDirections.model_validate_json(response.text)

        directives = {
            item.word_index: item
            for item in directions.directives
            if item.word_index < len(prosody.segments)
        }
        segments = _compose_segments(transcript, prosody, directives)
        if not segments:
            raise ValueError("Gemini kinetic plan could not be aligned to transcript")
        return KineticPlanResponse(
            model=self.config.model,
            interpretation=directions.interpretation,
            segments=segments,
        )


def _compose_segments(
    transcript: str,
    prosody: ProsodyResponse,
    directives: dict[int, object],
) -> list[KineticSegmentResponse]:
    output: list[KineticSegmentResponse] = []
    lower_text = transcript.casefold()
    cursor = 0
    for index, segment in enumerate(prosody.segments):
        token = segment.text.strip()
        if not token:
            continue
        match = lower_text.find(token.casefold(), cursor)
        if match < 0:
            continue
        if match > cursor:
            output.append(
                KineticSegmentResponse(
                    text=transcript[cursor:match],
                    motion="neutral",
                    intensity="subtle",
                )
            )
        end = match + len(token)
        directive = directives.get(index)
        base_motion = _acoustic_motion(segment, index, prosody)
        base_intensity = _acoustic_intensity(segment.emphasis)
        motion = getattr(directive, "motion", base_motion)
        semantic_intensity = getattr(directive, "intensity", "subtle")
        output.append(
            KineticSegmentResponse(
                text=transcript[match:end],
                motion=base_motion if segment.emphasis >= 0.65 else motion,
                intensity=_stronger_intensity(base_intensity, semantic_intensity),
            )
        )
        cursor = end
    if cursor == 0:
        return []
    if cursor < len(transcript):
        output.append(
            KineticSegmentResponse(
                text=transcript[cursor:],
                motion="neutral",
                intensity="subtle",
            )
        )
    return output


def _acoustic_motion(
    segment: SegmentProsody,
    index: int,
    prosody: ProsodyResponse,
) -> str:
    if segment.emphasis >= 0.65:
        return "impact"
    if segment.pause_after >= 0.30:
        return "settle"
    if index == len(prosody.segments) - 1:
        if prosody.utterance.intonation == "rising":
            return "rise"
        if prosody.utterance.intonation == "falling":
            return "settle"
    if (prosody.utterance.speed or 0) >= 0.78:
        return "rapid"
    if segment.emphasis >= 0.40:
        return "stretch"
    if segment.relative_loudness <= 0.20:
        return "soft"
    return "neutral"


def _acoustic_intensity(emphasis: float) -> str:
    if emphasis >= 0.72:
        return "strong"
    if emphasis >= 0.40:
        return "medium"
    return "subtle"


def _stronger_intensity(acoustic: str, semantic: str) -> str:
    levels = {"subtle": 0, "medium": 1, "strong": 2}
    return acoustic if levels[acoustic] >= levels.get(semantic, 0) else semantic
