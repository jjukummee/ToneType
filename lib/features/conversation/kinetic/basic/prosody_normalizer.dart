import 'dart:math' as math;

import '../../models/prosody_result.dart';
import 'basic_kinetic_types.dart';

class BasicProsodyNormalizer {
  const BasicProsodyNormalizer();

  Map<int, NormalizedWordProsody> normalize(ProsodyAnalysisResult prosody) {
    final segments = prosody.segments;
    if (segments.isEmpty) return const {};

    final loudness = _guardedMinMax([
      for (final segment in segments) segment.relativeLoudness,
    ]);
    final durationPerSyllable = [
      for (final segment in segments)
        segment.duration / math.max(1, _syllableCount(segment.text)),
    ];
    final duration = _guardedMinMax(durationPerSyllable);
    final durationMedian = _median(durationPerSyllable);
    final pitches = [
      for (final segment in segments)
        if (segment.relativePitch != null) segment.relativePitch!,
    ];
    final pitchMedian = pitches.isEmpty ? 0.5 : _median(pitches);
    final rawDeviation = [
      for (final segment in segments)
        segment.relativePitch == null
            ? 0.0
            : (segment.relativePitch! - pitchMedian).abs(),
    ];
    final pitchDeviation = _guardedMinMax(rawDeviation);

    return {
      for (var index = 0; index < segments.length; index++)
        index: NormalizedWordProsody(
          sourceIndex: index,
          loudness: loudness[index],
          pitchDeviation: pitchDeviation[index],
          duration: duration[index],
          durationRatio: durationMedian <= 0
              ? 1
              : (durationPerSyllable[index] / durationMedian).clamp(0.0, 3.0),
          energy: ((loudness[index] + prosody.utterance.energy) / 2).clamp(
            0.0,
            1.0,
          ),
          emphasis: segments[index].emphasis,
          pauseBefore: index == 0 ? 0 : segments[index - 1].pauseAfter,
          pauseAfter: segments[index].pauseAfter,
        ),
    };
  }

  List<double> _guardedMinMax(List<double> values) {
    if (values.isEmpty) return const [];
    if (values.length == 1) return const [0.5];
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final range = maximum - minimum;
    if (range < 0.06) return [for (final _ in values) 0.5];
    final blend = values.length == 2 ? 0.58 : 1.0;
    return [
      for (final value in values)
        (0.5 + (((value - minimum) / range) - 0.5) * blend).clamp(0.0, 1.0),
    ];
  }

  int _syllableCount(String text) {
    final hangul = text.runes.where(
      (codePoint) => codePoint >= 0xAC00 && codePoint <= 0xD7A3,
    );
    final count = hangul.length;
    return count > 0
        ? count
        : text.replaceAll(RegExp(r'\s|[,.!?…~]'), '').runes.length;
  }

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
