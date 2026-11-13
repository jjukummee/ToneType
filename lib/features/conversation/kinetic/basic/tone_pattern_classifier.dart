import 'dart:math' as math;

import '../../models/kinetic_segment.dart';
import '../../models/prosody_result.dart';
import 'basic_kinetic_config.dart';
import 'basic_kinetic_types.dart';

class ToneClassification {
  const ToneClassification({required this.pattern, required this.scores});

  final KineticPattern pattern;
  final Map<KineticPattern, double> scores;
}

class TonePatternClassifier {
  const TonePatternClassifier({this.config = const BasicKineticConfig()});

  final BasicKineticConfig config;

  ToneClassification classify({
    required String transcript,
    required ProsodyAnalysisResult prosody,
    required List<PhraseSalience> phrases,
  }) {
    if (transcript.trim().isEmpty || phrases.isEmpty) {
      return const ToneClassification(
        pattern: KineticPattern.neutral,
        scores: {KineticPattern.neutral: 1},
      );
    }

    final utterance = prosody.utterance;
    final pitch = utterance.pitch ?? 0.5;
    final speed = utterance.speed ?? 0.5;
    final energy = utterance.energy;
    final volume = utterance.volume;
    final maxSalience = phrases
        .map((phrase) => phrase.finalScore)
        .reduce(math.max);
    final maxAcoustic = phrases
        .map((phrase) => phrase.acousticScore)
        .reduce(math.max);
    final maxDuration = phrases
        .map((phrase) => phrase.maxDuration)
        .reduce(math.max);
    final maxDurationRatio = phrases
        .map((phrase) => phrase.maxDurationRatio)
        .reduce(math.max);
    final drawnOutEvidence = math.max(
      maxDuration,
      ((maxDurationRatio - 1) / 0.65).clamp(0.0, 1.0),
    );
    final maxPitchDeviation = phrases
        .map((phrase) => phrase.maxPitchDeviation)
        .reduce(math.max);
    final pauseDensity = phrases.length <= 1
        ? utterance.pause
        : phrases
                  .where(
                    (phrase) => phrase.pauseAfter >= config.meaningfulPause,
                  )
                  .length /
              (phrases.length - 1);

    bool has(String rule) =>
        phrases.any((phrase) => phrase.linguistic.matchedRules.contains(rule));

    final rising = utterance.intonation == ProsodyIntonation.rising ? 1.0 : 0.0;
    final falling = utterance.intonation == ProsodyIntonation.falling
        ? 1.0
        : 0.0;
    final questionMark = transcript.contains('?') ? 1.0 : 0.0;
    final exclamationMark = transcript.contains('!') ? 1.0 : 0.0;
    final repetition = phrases.any((phrase) => phrase.linguistic.repeated)
        ? 1.0
        : 0.0;
    final scores = <KineticPattern, double>{
      KineticPattern.repetition: repetition,
      KineticPattern.whisper:
          (1 - volume) * 0.30 +
          (1 - energy) * 0.30 +
          (has('secret_expression') ? 0.40 : 0),
      KineticPattern.hesitant:
          pauseDensity * 0.30 +
          (has('hesitation_expression') ? 0.38 : 0) +
          (has('ellipsis') ? 0.14 : 0) +
          (1 - energy) * 0.18,
      KineticPattern.urgent:
          speed * 0.16 +
          energy * 0.20 +
          maxSalience * 0.20 +
          (has('urgent_keyword') ? 0.36 : 0) +
          exclamationMark * 0.08,
      KineticPattern.excited:
          pitch * 0.16 +
          energy * 0.25 +
          speed * 0.10 +
          (has('exclamation_expression') ? 0.30 : 0) +
          exclamationMark * 0.19 +
          (has('exclamation_mark') ? 0.12 : 0),
      KineticPattern.surprise:
          rising * 0.30 +
          pitch * 0.20 +
          maxPitchDeviation * 0.15 +
          questionMark * 0.22 +
          exclamationMark * 0.13,
      KineticPattern.calm:
          (1 - energy) * 0.30 +
          (1 - speed) * 0.16 +
          pauseDensity * 0.16 +
          (has('calm_expression') ? 0.38 : 0),
      KineticPattern.drawnOut:
          drawnOutEvidence * 0.62 +
          (1 - speed) * 0.16 +
          (transcript.contains('~') ? 0.22 : 0),
      KineticPattern.firm:
          falling * 0.22 +
          maxSalience * 0.22 +
          (has('firm_expression') || has('negative_expression') ? 0.38 : 0) +
          (1 - (speed - 0.5).abs() * 2).clamp(0.0, 1.0) * 0.18,
      KineticPattern.strongEmphasis:
          maxSalience * 0.45 +
          maxAcoustic * 0.35 +
          energy * 0.12 +
          (has('emphasis_keyword') ? 0.23 : 0),
      KineticPattern.question: rising * 0.55 + questionMark * 0.45,
      KineticPattern.neutral: 0.42,
    };

    const thresholds = <KineticPattern, double>{
      KineticPattern.repetition: 0.80,
      KineticPattern.whisper: 0.66,
      KineticPattern.hesitant: 0.62,
      KineticPattern.urgent: 0.64,
      KineticPattern.excited: 0.62,
      KineticPattern.surprise: 0.68,
      KineticPattern.calm: 0.64,
      KineticPattern.drawnOut: 0.69,
      KineticPattern.firm: 0.66,
      KineticPattern.strongEmphasis: 0.50,
      KineticPattern.question: 0.72,
      KineticPattern.neutral: 0,
    };
    final eligible = scores.entries
        .where((entry) => entry.value >= (thresholds[entry.key] ?? 1))
        .toList();
    eligible.sort((a, b) => b.value.compareTo(a.value));
    var pattern = eligible.isEmpty
        ? KineticPattern.neutral
        : eligible.first.key;
    if (pattern == KineticPattern.strongEmphasis &&
        scores[KineticPattern.drawnOut]! >=
            thresholds[KineticPattern.drawnOut]! &&
        maxAcoustic < config.dominantAcousticImpact) {
      pattern = KineticPattern.drawnOut;
    } else if (pattern == KineticPattern.drawnOut &&
        maxAcoustic >= config.dominantAcousticImpact &&
        scores[KineticPattern.strongEmphasis]! >=
            thresholds[KineticPattern.strongEmphasis]!) {
      pattern = KineticPattern.strongEmphasis;
    }
    return ToneClassification(pattern: pattern, scores: scores);
  }
}
