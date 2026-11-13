import '../../models/kinetic_segment.dart';

class KineticLayoutResolver {
  const KineticLayoutResolver();

  KineticLayout resolve({
    required KineticPattern pattern,
    required List<KineticSegment> segments,
  }) {
    if (segments.length <= 1) return KineticLayout.inline;
    final dominantIndex = _dominantIndex(segments);
    return switch (pattern) {
      KineticPattern.urgent =>
        segments.length >= 3
            ? KineticLayout.verticalBuild
            : KineticLayout.focusCenter,
      KineticPattern.excited => KineticLayout.verticalBuild,
      KineticPattern.repetition => KineticLayout.staggered,
      KineticPattern.whisper || KineticPattern.calm => KineticLayout.quietSpace,
      KineticPattern.drawnOut => KineticLayout.wideStretch,
      KineticPattern.firm => KineticLayout.focusEnd,
      KineticPattern.strongEmphasis =>
        dominantIndex >= segments.length - 2
            ? KineticLayout.focusEnd
            : KineticLayout.focusCenter,
      KineticPattern.hesitant => KineticLayout.staggered,
      KineticPattern.surprise ||
      KineticPattern.question => KineticLayout.focusEnd,
      KineticPattern.neutral =>
        segments.any((segment) => segment.motion != KineticMotion.neutral)
            ? segments.length >= 4
                  ? KineticLayout.stacked
                  : KineticLayout.focusEnd
            : KineticLayout.inline,
    };
  }

  int _dominantIndex(List<KineticSegment> segments) {
    var best = 0;
    for (var index = 1; index < segments.length; index++) {
      if (segments[index].salience > segments[best].salience) best = index;
    }
    return best;
  }
}
