import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/features/conversation/kinetic/basic/basic_kinetic_planner.dart';
import 'package:tonetype/features/conversation/kinetic/kinetic_planner.dart';
import 'package:tonetype/features/conversation/models/prosody_result.dart';

/// A live session only keeps the most recent audio, so the opening of a long
/// utterance arrives with no word timings. The planner must still break it into
/// readable phrases rather than emitting one undifferentiated block.
void main() {
  const head =
      '음 근데 이것도 저만의 규칙을 정하고 이거는 진짜 오랫동안 지키고 있는 건데 '
      '설거지는 하루를 넘기지 말자 요렇게 그 규칙을 정했어요 ';
  const tail = '그래서 어떤 습관을 만들 때 중요한 게 원래 하는 일에 더하면 쉽다';
  const transcript = '$head$tail';

  ProsodyAnalysisResult prosodyForTailOnly() {
    final words = tail.split(' ');
    var cursor = 0.0;
    final segments = <ProsodySegmentResult>[];
    for (var index = 0; index < words.length; index++) {
      final start = cursor;
      cursor += 0.42;
      segments.add(
        ProsodySegmentResult(
          text: words[index],
          start: start,
          end: cursor,
          duration: 0.42,
          relativeLoudness: 0.4 + (index % 4) * 0.15,
          relativePitch: 0.45 + (index % 3) * 0.12,
          pauseAfter: 0.05,
          emphasis: 0.3 + (index % 5) * 0.12,
        ),
      );
    }
    return ProsodyAnalysisResult(
      utterance: const ProsodyUtterance(
        volume: 0.55,
        pitch: 0.5,
        speed: 0.5,
        energy: 0.6,
        pause: 0.2,
        intonation: ProsodyIntonation.falling,
      ),
      segments: segments,
    );
  }

  test('unmeasured speech is split instead of collapsing into one phrase', () {
    final plan = const BasicKineticPlanner().plan(
      KineticPlannerInput(
        displayText: transcript,
        prosody: prosodyForTailOnly(),
      ),
    );

    final longest = plan.segments
        .map((segment) => segment.text.length)
        .reduce((a, b) => a > b ? a : b);

    expect(plan.segments.length, greaterThan(6));
    expect(longest, lessThan(transcript.length ~/ 3));
    // Losslessness still holds: nothing may be dropped or reordered.
    expect(plan.transcript, transcript);
  });

  test('the measured tail still drives its own typography', () {
    final plan = const BasicKineticPlanner().plan(
      KineticPlannerInput(
        displayText: transcript,
        prosody: prosodyForTailOnly(),
      ),
    );

    final tailSegments = plan.segments.where(
      (segment) => tail.contains(segment.text.trim()),
    );
    expect(tailSegments, isNotEmpty);
    expect(
      tailSegments.map((segment) => segment.salience).toSet().length,
      greaterThan(1),
    );
  });
}
