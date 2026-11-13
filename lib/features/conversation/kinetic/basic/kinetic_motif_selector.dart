import '../../models/kinetic_segment.dart';

class KineticMotif {
  const KineticMotif({
    required this.primary,
    required this.supporting,
    required this.ending,
  });

  final KineticMotion primary;
  final KineticMotion supporting;
  final KineticMotion ending;
}

class KineticMotifSelector {
  const KineticMotifSelector();

  KineticMotif select(KineticPattern pattern) => switch (pattern) {
    KineticPattern.strongEmphasis => const KineticMotif(
      primary: KineticMotion.impact,
      supporting: KineticMotion.stretch,
      ending: KineticMotion.settle,
    ),
    KineticPattern.surprise || KineticPattern.question => const KineticMotif(
      primary: KineticMotion.rise,
      supporting: KineticMotion.stagger,
      ending: KineticMotion.rise,
    ),
    KineticPattern.urgent => const KineticMotif(
      primary: KineticMotion.impact,
      supporting: KineticMotion.rapid,
      ending: KineticMotion.settle,
    ),
    KineticPattern.hesitant => const KineticMotif(
      primary: KineticMotion.stagger,
      supporting: KineticMotion.soft,
      ending: KineticMotion.soft,
    ),
    KineticPattern.calm => const KineticMotif(
      primary: KineticMotion.soft,
      supporting: KineticMotion.stretch,
      ending: KineticMotion.settle,
    ),
    KineticPattern.whisper => const KineticMotif(
      primary: KineticMotion.whisper,
      supporting: KineticMotion.soft,
      ending: KineticMotion.whisper,
    ),
    KineticPattern.excited => const KineticMotif(
      primary: KineticMotion.impact,
      supporting: KineticMotion.rise,
      ending: KineticMotion.impact,
    ),
    KineticPattern.firm => const KineticMotif(
      primary: KineticMotion.impact,
      supporting: KineticMotion.neutral,
      ending: KineticMotion.settle,
    ),
    KineticPattern.drawnOut => const KineticMotif(
      primary: KineticMotion.stretch,
      supporting: KineticMotion.soft,
      ending: KineticMotion.settle,
    ),
    KineticPattern.repetition => const KineticMotif(
      primary: KineticMotion.impact,
      supporting: KineticMotion.rapid,
      ending: KineticMotion.impact,
    ),
    KineticPattern.neutral => const KineticMotif(
      primary: KineticMotion.soft,
      supporting: KineticMotion.neutral,
      ending: KineticMotion.settle,
    ),
  };
}
