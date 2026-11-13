import 'basic_kinetic_types.dart';
import 'korean_kinetic_rules.dart';

class KoreanLinguisticAnalyzer {
  const KoreanLinguisticAnalyzer();

  List<LinguisticFeatures> analyze(List<PhraseUnit> phrases) {
    final phraseKeys = [
      for (final phrase in phrases) normalizeKoreanToken(phrase.text),
    ];
    final wordSequence = [
      for (final phrase in phrases)
        for (final word in phrase.words) word.normalizedText,
    ];

    return [
      for (var index = 0; index < phrases.length; index++)
        _analyzePhrase(
          phrases[index],
          repeated:
              (index > 0 && phraseKeys[index - 1] == phraseKeys[index]) ||
              (index + 1 < phrases.length &&
                  phraseKeys[index + 1] == phraseKeys[index]) ||
              phrases[index].words.any(
                (word) => _isRepeatedWord(word.normalizedText, wordSequence),
              ),
        ),
    ];
  }

  LinguisticFeatures _analyzePhrase(
    PhraseUnit phrase, {
    required bool repeated,
  }) {
    final normalized = normalizeKoreanToken(phrase.text);
    final rules = <String>{};
    var score = 0.12;

    void match(String rule, Set<String> vocabulary, double value) {
      if (vocabulary.any(
        (term) => normalized.contains(normalizeKoreanToken(term)),
      )) {
        rules.add(rule);
        if (value > score) score = value;
      }
    }

    match('emphasis_keyword', KoreanKineticRules.emphasis, 0.68);
    match('urgent_keyword', KoreanKineticRules.urgent, 0.86);
    match('negative_expression', KoreanKineticRules.negative, 0.70);
    match('exclamation_expression', KoreanKineticRules.exclamation, 0.74);
    match('softener_expression', KoreanKineticRules.softener, 0.32);
    match('hesitation_expression', KoreanKineticRules.hesitation, 0.56);
    match('firm_expression', KoreanKineticRules.firm, 0.80);
    match('secret_expression', KoreanKineticRules.secret, 0.66);
    match('calm_expression', KoreanKineticRules.calm, 0.48);

    if (phrase.text.contains('!')) {
      rules.add('exclamation_mark');
      score = score < 0.58 ? 0.58 : score;
    }
    if (phrase.text.contains('?')) {
      rules.add('question_mark');
      score = score < 0.48 ? 0.48 : score;
    }
    if (phrase.text.contains('...') || phrase.text.contains('…')) {
      rules.add('ellipsis');
      score = score < 0.40 ? 0.40 : score;
    }
    if (repeated) {
      rules.add('repetition');
      score = score < 0.72 ? 0.72 : score;
    }
    if (phrase.isLast &&
        (rules.contains('negative_expression') ||
            rules.contains('firm_expression'))) {
      rules.add('strong_ending');
      score += 0.08;
    }

    return LinguisticFeatures(
      score: score.clamp(0.0, 1.0),
      matchedRules: rules,
      repeated: repeated,
    );
  }

  bool _isRepeatedWord(String word, List<String> sequence) {
    if (word.isEmpty) return false;
    for (var index = 1; index < sequence.length; index++) {
      if (sequence[index] == word && sequence[index - 1] == word) return true;
    }
    return false;
  }
}
