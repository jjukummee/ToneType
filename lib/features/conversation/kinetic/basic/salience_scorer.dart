import 'dart:math' as math;

import 'basic_kinetic_config.dart';
import 'basic_kinetic_types.dart';

class SalienceScorer {
  const SalienceScorer({this.config = const BasicKineticConfig()});

  final BasicKineticConfig config;

  List<PhraseSalience> score({
    required List<PhraseUnit> phrases,
    required List<LinguisticFeatures> linguistic,
    required Map<int, NormalizedWordProsody> normalized,
  }) {
    return [
      for (var index = 0; index < phrases.length; index++)
        _scorePhrase(phrases[index], linguistic[index], normalized),
    ];
  }

  PhraseSalience _scorePhrase(
    PhraseUnit phrase,
    LinguisticFeatures linguistic,
    Map<int, NormalizedWordProsody> normalized,
  ) {
    final words = phrase.words
        .map((word) => normalized[word.sourceIndex])
        .whereType<NormalizedWordProsody>()
        .toList(growable: false);
    if (words.isEmpty) {
      return PhraseSalience(
        phrase: phrase,
        linguistic: linguistic,
        acousticScore: 0.25,
        finalScore:
            (0.25 * config.acousticWeight +
                    linguistic.score * config.linguisticWeight)
                .clamp(0.0, 1.0),
        maxDuration: 0.5,
        maxDurationRatio: 1,
        maxPitchDeviation: 0,
        pauseBefore: 0,
        pauseAfter: 0,
      );
    }

    final wordScores = [
      for (final word in words)
        ((word.loudness * config.loudnessWeight +
                        word.pitchDeviation * config.pitchDeviationWeight +
                        word.duration * config.durationWeight +
                        word.energy * config.energyWeight) *
                    0.76 +
                word.emphasis * 0.24)
            .clamp(0.0, 1.0),
    ];
    final maximum = wordScores.reduce(math.max);
    final average = wordScores.reduce((a, b) => a + b) / wordScores.length;
    final acoustic = maximum * 0.65 + average * 0.35;
    var finalScore =
        acoustic * config.acousticWeight +
        linguistic.score * config.linguisticWeight;
    if (linguistic.repeated) finalScore += 0.06;
    if (phrase.isLast && linguistic.matches('strong_ending')) {
      finalScore += 0.06;
    }

    return PhraseSalience(
      phrase: phrase,
      linguistic: linguistic,
      acousticScore: acoustic.clamp(0.0, 1.0),
      finalScore: finalScore.clamp(0.0, 1.0),
      maxDuration: words.map((word) => word.duration).reduce(math.max),
      maxDurationRatio: words
          .map((word) => word.durationRatio)
          .reduce(math.max),
      maxPitchDeviation: words
          .map((word) => word.pitchDeviation)
          .reduce(math.max),
      pauseBefore: words.first.pauseBefore,
      pauseAfter: words.last.pauseAfter,
    );
  }
}
