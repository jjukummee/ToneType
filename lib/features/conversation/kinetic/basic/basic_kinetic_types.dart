import '../../models/prosody_result.dart';

class AlignedWord {
  const AlignedWord({
    required this.sourceIndex,
    required this.text,
    required this.normalizedText,
    required this.transcriptStart,
    required this.transcriptEnd,
    required this.prosody,
  });

  final int sourceIndex;
  final String text;
  final String normalizedText;
  final int transcriptStart;
  final int transcriptEnd;
  final ProsodySegmentResult prosody;
}

class PhraseUnit {
  const PhraseUnit({
    required this.text,
    required this.words,
    required this.index,
    required this.isLast,
  });

  final String text;
  final List<AlignedWord> words;
  final int index;
  final bool isLast;
}

class NormalizedWordProsody {
  const NormalizedWordProsody({
    required this.sourceIndex,
    required this.loudness,
    required this.pitchDeviation,
    required this.duration,
    required this.durationRatio,
    required this.energy,
    required this.emphasis,
    required this.pauseBefore,
    required this.pauseAfter,
  });

  final int sourceIndex;
  final double loudness;
  final double pitchDeviation;
  final double duration;
  final double durationRatio;
  final double energy;
  final double emphasis;
  final double pauseBefore;
  final double pauseAfter;
}

class LinguisticFeatures {
  const LinguisticFeatures({
    required this.score,
    required this.matchedRules,
    required this.repeated,
  });

  final double score;
  final Set<String> matchedRules;
  final bool repeated;

  bool matches(String rule) => matchedRules.contains(rule);
}

class PhraseSalience {
  const PhraseSalience({
    required this.phrase,
    required this.linguistic,
    required this.acousticScore,
    required this.finalScore,
    required this.maxDuration,
    required this.maxDurationRatio,
    required this.maxPitchDeviation,
    required this.pauseBefore,
    required this.pauseAfter,
  });

  final PhraseUnit phrase;
  final LinguisticFeatures linguistic;
  final double acousticScore;
  final double finalScore;
  final double maxDuration;
  final double maxDurationRatio;
  final double maxPitchDeviation;
  final double pauseBefore;
  final double pauseAfter;
}

String normalizeKoreanToken(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'''[\s,.!?…~"'“”‘’()\[\]{}:;]+'''), '')
    .trim();
