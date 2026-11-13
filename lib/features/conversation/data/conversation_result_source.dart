import '../../../core/models/app_language.dart';
import '../../../core/text/korean_text_normalizer.dart';
import '../kinetic/basic/basic_text_kinetic_planner.dart';
import '../models/conversation_state.dart';

/// Boundary between text input and presentation.
abstract interface class ConversationResultSource {
  Future<ConversationStateModel> finalResult({
    required String recognizedText,
    required LanguagePair languagePair,
  });
}

class SameLanguageConversationResultSource implements ConversationResultSource {
  const SameLanguageConversationResultSource({
    this.kineticPlanner = const BasicTextKineticPlanner(),
  });

  final BasicTextKineticPlanner kineticPlanner;

  @override
  Future<ConversationStateModel> finalResult({
    required String recognizedText,
    required LanguagePair languagePair,
  }) async {
    final source = recognizedText.trim();
    if (!languagePair.isSameLanguage) {
      return ConversationStateModel.error('다른 언어로 번역하는 서버가 연결되지 않았어요.');
    }
    final resultText = languagePair.target == AppLanguage.korean
        ? KoreanTextNormalizer.normalize(source)
        : source;
    return ConversationStateModel(
      state: ConversationUiState.finalTranslation,
      originalText: '“$source”',
      finalTranslation: resultText,
      kineticPlan: kineticPlanner.plan(resultText),
    );
  }
}
