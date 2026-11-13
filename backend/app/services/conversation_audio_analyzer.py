import logging

from app.core.errors import ProsodyError
from app.schemas.speech import SpeechAnalysisResponse
from app.services.kinetic import KineticDirector
from app.services.prosody import ProsodyAnalyzer
from app.services.speech import SpeechTranscriber

logger = logging.getLogger(__name__)


class ConversationAudioAnalyzer:
    def __init__(
        self,
        transcriber: SpeechTranscriber,
        prosody_analyzer: ProsodyAnalyzer | None = None,
        kinetic_director: KineticDirector | None = None,
    ) -> None:
        self.transcriber = transcriber
        self.prosody_analyzer = prosody_analyzer or ProsodyAnalyzer()
        self.kinetic_director = kinetic_director

    def analyze(
        self,
        content: bytes,
        *,
        filename: str | None,
        source_language: str,
        target_language: str,
        conversation_context: str = "일상",
        kinetic_mode: str = "basic",
        debug: bool = False,
    ) -> SpeechAnalysisResponse:
        source = source_language.replace("_", "-")
        target = target_language.replace("_", "-")
        if source.split("-")[0] != target.split("-")[0]:
            raise ProsodyError(
                "translation_not_configured",
                "Cross-language translation is not configured yet.",
                422,
            )

        # Reject malformed, oversized, silent, or out-of-range audio before a
        # billable external transcription call.
        self.prosody_analyzer.preprocessor.process(content, filename)
        transcription = self.transcriber.transcribe(content, language=source)
        prosody = self.prosody_analyzer.analyze(
            content,
            filename=filename,
            language=source,
            words=transcription.words,
            debug=debug,
        )
        kinetic = None
        kinetic_fallback = False
        if kinetic_mode == "hybrid":
            if self.kinetic_director is None:
                kinetic_fallback = True
            else:
                try:
                    kinetic = self.kinetic_director.generate(
                        transcript=transcription.text,
                        language=source,
                        conversation_context=conversation_context,
                        prosody=prosody,
                    )
                except Exception as error:
                    kinetic_fallback = True
                    logger.warning(
                        "kinetic_generation_failed",
                        extra={"error_type": type(error).__name__},
                    )
        return SpeechAnalysisResponse(
            transcript=transcription.text,
            detected_language=transcription.language,
            words=transcription.words,
            prosody=prosody,
            kinetic=kinetic,
            kinetic_fallback=kinetic_fallback,
        )
