import 'dart:math' as math;

import '../../models/kinetic_segment.dart';
import '../../models/prosody_result.dart';
import 'basic_kinetic_config.dart';
import 'basic_kinetic_types.dart';

class KineticTimingScheduler {
  const KineticTimingScheduler({this.config = const BasicKineticConfig()});

  final BasicKineticConfig config;

  List<KineticSegment> schedule({
    required List<KineticSegment> segments,
    required List<PhraseSalience> phrases,
    required ProsodyAnalysisResult prosody,
  }) {
    final output = <KineticSegment>[];
    var timelineMs = 0;
    final speed = prosody.utterance.speed ?? 0.5;
    for (var index = 0; index < segments.length; index++) {
      final phrase = phrases[index];
      final pauseMs = index == 0 ? 0 : _compressPause(phrase.pauseBefore);
      timelineMs = math.min(1800, timelineMs + pauseMs);
      final duration = _durationFor(
        segments[index].motion,
        phrase: phrase,
        speed: speed,
      );
      final hold = switch (segments[index].motion) {
        KineticMotion.impact => 110,
        KineticMotion.soft || KineticMotion.whisper => 150,
        KineticMotion.stretch => 140,
        _ => 80,
      };
      output.add(
        segments[index].copyWith(
          timing: KineticTiming(
            startDelayMs: timelineMs,
            durationMs: duration,
            holdDurationMs: hold,
            sequenceIndex: index,
          ),
        ),
      );
      timelineMs = math.min(2200, timelineMs + (duration * 0.58).round());
    }
    return output;
  }

  int _durationFor(
    KineticMotion motion, {
    required PhraseSalience phrase,
    required double speed,
  }) {
    final preset = switch (motion) {
      KineticMotion.impact => 340,
      KineticMotion.rapid => 280,
      KineticMotion.rise => 380,
      KineticMotion.settle => 440,
      KineticMotion.stagger => 480,
      KineticMotion.soft || KineticMotion.whisper => 560,
      KineticMotion.stretch => 620,
      KineticMotion.neutral => 300,
    };
    final spokenMs = phrase.phrase.words.isEmpty
        ? preset
        : (phrase.phrase.words.fold<double>(
                    0,
                    (sum, word) => sum + word.prosody.duration,
                  ) *
                  620)
              .round();
    final speedFactor = 1.12 - speed * 0.24;
    return ((preset * 0.72 + spokenMs * 0.28) * speedFactor).round().clamp(
      config.minAnimationMs,
      config.maxAnimationMs,
    );
  }

  int _compressPause(double seconds) {
    if (seconds < 0.06) return 0;
    if (seconds < 0.15) return 70;
    if (seconds < 0.35) return (120 + seconds * 260).round();
    return (210 + math.sqrt(seconds) * 150).round().clamp(
      0,
      config.maxCompressedPauseMs,
    );
  }
}
