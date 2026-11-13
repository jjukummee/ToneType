import '../../models/kinetic_segment.dart';
import '../../models/prosody_result.dart';
import '../kinetic_planner.dart';
import 'basic_kinetic_planner.dart';

/// Language-only fallback used for keyboard input.
///
/// It deliberately avoids inventing acoustic variation. Punctuation supplies
/// only rhythm and intonation hints, while Korean rules provide the motif.
class BasicTextKineticPlanner {
  const BasicTextKineticPlanner({this.planner = const BasicKineticPlanner()});

  final BasicKineticPlanner planner;

  KineticPlan plan(String transcript, {bool debug = false}) {
    if (transcript.isEmpty) return KineticPlan.neutral(transcript);
    final matches = RegExp(r'\S+').allMatches(transcript).toList();
    if (matches.isEmpty) return KineticPlan.neutral(transcript);

    var cursor = 0.0;
    final segments = <ProsodySegmentResult>[];
    for (var index = 0; index < matches.length; index++) {
      final text = matches[index].group(0)!;
      final syllables = _visibleLength(text);
      final duration = 0.10 + syllables * 0.085;
      final pause = _pauseAfter(text);
      segments.add(
        ProsodySegmentResult(
          text: text,
          start: cursor,
          end: cursor + duration,
          duration: duration,
          relativeLoudness: 0.5,
          relativePitch: 0.5,
          pauseAfter: pause,
          emphasis: _textualEmphasis(text),
        ),
      );
      cursor += duration + pause;
    }

    final hasQuestion = transcript.contains('?');
    final hasExclamation = transcript.contains('!');
    final hasEllipsis = transcript.contains('...') || transcript.contains('…');
    final result = planner.plan(
      KineticPlannerInput(
        displayText: transcript,
        debug: debug,
        prosody: ProsodyAnalysisResult(
          utterance: ProsodyUtterance(
            volume: hasEllipsis ? 0.42 : 0.5,
            pitch: hasQuestion ? 0.68 : 0.5,
            speed: hasEllipsis ? 0.38 : (hasExclamation ? 0.62 : 0.5),
            energy: hasEllipsis ? 0.38 : (hasExclamation ? 0.7 : 0.5),
            pause:
                segments.fold<double>(
                  0,
                  (sum, segment) => sum + segment.pauseAfter,
                ) /
                segments.length,
            intonation: hasQuestion
                ? ProsodyIntonation.rising
                : transcript.trimRight().endsWith('.') || hasExclamation
                ? ProsodyIntonation.falling
                : ProsodyIntonation.flat,
          ),
          segments: segments,
        ),
      ),
    );
    return _ensureVisibleComposition(result);
  }

  KineticPlan _ensureVisibleComposition(KineticPlan plan) {
    if (plan.segments.isEmpty) return plan;
    final hasMotion = plan.segments.any(
      (segment) => segment.motion != KineticMotion.neutral,
    );
    var segments = plan.segments;
    if (!hasMotion) {
      final target = segments.length - 1;
      segments = [
        for (var index = 0; index < segments.length; index++)
          index == target
              ? segments[index].copyWith(
                  motion: KineticMotion.settle,
                  intensity: KineticIntensity.medium,
                  salience: 0.5,
                )
              : segments[index],
      ];
    }
    final layout = plan.layout == KineticLayout.inline && segments.length > 1
        ? segments.length >= 4
              ? KineticLayout.stacked
              : KineticLayout.focusEnd
        : plan.layout;
    return KineticPlan(
      mode: plan.mode,
      pattern: plan.pattern,
      layout: layout,
      segments: segments,
      interpretation: plan.interpretation,
    );
  }

  int _visibleLength(String text) {
    final value = text.replaceAll(RegExp(r'[\s,.!?…~]'), '');
    return value.runes.isEmpty ? 1 : value.runes.length;
  }

  double _pauseAfter(String text) {
    if (text.contains('...') || text.contains('…')) return 0.42;
    if (RegExp(r'[!?]$').hasMatch(text)) return 0.14;
    if (text.endsWith(',')) return 0.18;
    if (text.endsWith('.')) return 0.12;
    return 0.04;
  }

  double _textualEmphasis(String text) {
    if (text.contains('!')) return 0.64;
    if (text.contains('?')) return 0.58;
    return 0.5;
  }
}
