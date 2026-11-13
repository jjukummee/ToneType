import '../../models/kinetic_segment.dart';
import '../../models/prosody_result.dart';
import 'basic_kinetic_config.dart';
import 'basic_kinetic_types.dart';
import 'kinetic_motif_selector.dart';

class MotionResolver {
  const MotionResolver({this.config = const BasicKineticConfig()});

  final BasicKineticConfig config;

  List<KineticSegment> resolve({
    required List<PhraseSalience> phrases,
    required KineticPattern pattern,
    required KineticMotif motif,
    required ProsodyAnalysisResult prosody,
    required bool debug,
  }) {
    if (phrases.isEmpty) return const [];
    final dominant = phrases.reduce(
      (current, next) => next.finalScore > current.finalScore ? next : current,
    );

    return [
      for (final phrase in phrases)
        KineticSegment(
          text: phrase.phrase.text,
          motion: _motionFor(
            phrase,
            dominant: identical(phrase, dominant),
            pattern: pattern,
            motif: motif,
            intonation: prosody.utterance.intonation,
          ),
          intensity: _intensityFor(phrase.finalScore),
          salience: phrase.finalScore,
          debug: debug
              ? KineticDebugInfo(
                  acousticScore: phrase.acousticScore,
                  linguisticScore: phrase.linguistic.score,
                  finalSalience: phrase.finalScore,
                  matchedRules: phrase.linguistic.matchedRules.toList()..sort(),
                )
              : null,
        ),
    ];
  }

  KineticMotion _motionFor(
    PhraseSalience phrase, {
    required bool dominant,
    required KineticPattern pattern,
    required KineticMotif motif,
    required ProsodyIntonation intonation,
  }) {
    final rules = phrase.linguistic.matchedRules;
    if (phrase.linguistic.repeated) return KineticMotion.rapid;
    // Sentence-level intent has priority over a local duration peak. Korean
    // one-syllable words naturally have a longer duration per syllable, so a
    // duration-only early return can otherwise turn commands or whispers into
    // an unrelated stretch motif.
    if (pattern == KineticPattern.drawnOut) {
      return KineticMotion.stretch;
    }
    if (pattern == KineticPattern.whisper) {
      return dominant ? KineticMotion.whisper : KineticMotion.soft;
    }
    if (pattern == KineticPattern.hesitant) {
      return phrase.pauseAfter >= config.meaningfulPause ||
              rules.contains('ellipsis')
          ? KineticMotion.stagger
          : KineticMotion.soft;
    }
    if ((pattern == KineticPattern.neutral || pattern == KineticPattern.calm) &&
        phrase.maxDuration >= config.drawnOutDuration &&
        phrase.maxDurationRatio >= config.drawnOutDurationRatio) {
      return KineticMotion.stretch;
    }
    if (pattern == KineticPattern.calm) {
      if (phrase.phrase.isLast) return KineticMotion.settle;
      return dominant ? KineticMotion.soft : KineticMotion.stretch;
    }
    if (pattern == KineticPattern.repetition) {
      return phrase.phrase.isLast && !phrase.linguistic.repeated
          ? motif.primary
          : motif.supporting;
    }
    if (pattern == KineticPattern.surprise ||
        pattern == KineticPattern.question) {
      return phrase.phrase.isLast || rules.contains('question_mark')
          ? KineticMotion.rise
          : dominant
          ? KineticMotion.impact
          : motif.supporting;
    }
    if (pattern == KineticPattern.urgent) {
      if (dominant) return motif.primary;
      if (rules.contains('urgent_keyword')) return motif.supporting;
      if (phrase.phrase.isLast && intonation == ProsodyIntonation.falling) {
        return motif.ending;
      }
    }
    if (pattern == KineticPattern.excited) {
      if (dominant || phrase.phrase.isLast) return motif.primary;
      if (rules.contains('emphasis_keyword') ||
          rules.contains('exclamation_expression')) {
        return motif.supporting;
      }
    }
    if (pattern == KineticPattern.firm) {
      if (phrase.phrase.isLast) return motif.ending;
      if (dominant) return motif.primary;
    }
    if (pattern == KineticPattern.strongEmphasis && dominant) {
      return motif.primary;
    }
    if (pattern == KineticPattern.neutral &&
        dominant &&
        phrase.acousticScore >= config.dominantAcousticImpact) {
      return KineticMotion.impact;
    }
    if (phrase.maxDuration >= config.drawnOutDuration &&
        phrase.maxDurationRatio >= config.drawnOutDurationRatio) {
      return KineticMotion.stretch;
    }
    if (phrase.pauseAfter >= config.meaningfulPause) {
      return KineticMotion.stagger;
    }
    if (phrase.phrase.isLast && intonation == ProsodyIntonation.rising) {
      return KineticMotion.rise;
    }
    if (phrase.phrase.isLast &&
        intonation == ProsodyIntonation.falling &&
        phrase.finalScore >= config.mediumSalience) {
      return KineticMotion.settle;
    }
    if (dominant && phrase.finalScore >= config.mediumSalience) {
      return motif.primary;
    }
    return KineticMotion.neutral;
  }

  KineticIntensity _intensityFor(double salience) {
    if (salience >= config.strongSalience) return KineticIntensity.strong;
    if (salience >= config.mediumSalience) return KineticIntensity.medium;
    return KineticIntensity.subtle;
  }
}
