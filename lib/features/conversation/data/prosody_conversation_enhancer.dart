import '../../../core/text/korean_text_normalizer.dart';
import '../kinetic/prosody_kinetic_planner.dart';
import '../models/conversation_state.dart';
import '../models/kinetic_segment.dart';
import '../models/prosody_result.dart';
import '../models/speech_capture_mode.dart';

class ProsodyConversationEnhancer {
  const ProsodyConversationEnhancer({
    this.planner = const ProsodyKineticPlanner(),
  });

  final ProsodyKineticPlanner planner;

  ConversationStateModel enhance({
    required ConversationStateModel translation,
    required ProsodyAnalysisResult prosody,
    KineticPlan? kineticPlan,
    KineticResultSource kineticSource = KineticResultSource.basic,
    String? kineticInterpretation,
    SpeechCaptureMode analysisMode = SpeechCaptureMode.single,
  }) {
    if (translation.state != ConversationUiState.finalTranslation) {
      return translation;
    }
    final measuredTone = ConversationToneSummary.fromProsody(
      prosody,
      transcript: translation.finalTranslation,
      captureMode: analysisMode,
    );
    final emphasizedWord = measuredTone.emphasizedWord;
    final tone = emphasizedWord == null
        ? measuredTone
        : measuredTone.copyWith(
            emphasizedWord: KoreanTextNormalizer.normalize(emphasizedWord),
          );
    final suppliedPlanMatches =
        kineticPlan?.transcript == translation.finalTranslation;
    return ConversationStateModel(
      state: translation.state,
      originalText: translation.originalText,
      finalTranslation: translation.finalTranslation,
      statusMessage: translation.statusMessage,
      tone: tone,
      kineticSource: suppliedPlanMatches
          ? kineticSource
          : kineticPlan == null
          ? kineticSource
          : KineticResultSource.basicFallback,
      kineticInterpretation: suppliedPlanMatches ? kineticInterpretation : null,
      kineticPlan:
          (suppliedPlanMatches ? kineticPlan : null) ??
          planner.buildPlan(
            displayText: translation.finalTranslation,
            prosody: prosody,
          ),
    );
  }
}
