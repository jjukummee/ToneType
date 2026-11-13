import 'dart:math' as math;

import '../../models/kinetic_segment.dart';

class KineticConstraintEngine {
  const KineticConstraintEngine();

  List<KineticSegment> apply(List<KineticSegment> input) {
    if (input.length <= 1) return input;
    final output = [...input];
    final strongLimit = input.length <= 4
        ? 1
        : input.length <= 8
        ? 2
        : 3;
    final ranked = List<int>.generate(input.length, (index) => index)
      ..sort((a, b) => input[b].salience.compareTo(input[a].salience));
    final allowedStrong = <int>{};
    for (final index in ranked) {
      if (input[index].intensity != KineticIntensity.strong) continue;
      final adjacent = allowedStrong.any((other) => (other - index).abs() == 1);
      if (!adjacent && allowedStrong.length < strongLimit) {
        allowedStrong.add(index);
      }
    }
    for (var index = 0; index < output.length; index++) {
      if (output[index].intensity == KineticIntensity.strong &&
          !allowedStrong.contains(index)) {
        output[index] = output[index].copyWith(
          intensity: KineticIntensity.medium,
        );
      }
    }

    final maxMoving = math.max(1, (output.length * 0.75).ceil());
    final moving = ranked
        .where((index) => output[index].motion != KineticMotion.neutral)
        .toList();
    for (final index in moving.skip(maxMoving)) {
      output[index] = output[index].copyWith(
        motion: KineticMotion.neutral,
        intensity: output[index].intensity == KineticIntensity.strong
            ? KineticIntensity.medium
            : output[index].intensity,
      );
    }

    if (output.length >= 3 &&
        output.every((segment) => segment.motion != KineticMotion.neutral)) {
      final quietest = ranked.last;
      output[quietest] = output[quietest].copyWith(
        motion: KineticMotion.neutral,
        intensity: KineticIntensity.subtle,
      );
    }
    return output;
  }
}
