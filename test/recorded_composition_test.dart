import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_kinetic_types.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/recorded_prosody_adapter.dart';
import 'package:tonetype/features/conversation/models/prosody_result.dart';

const _text = '오늘은 진짜 오랫동안 기다린 소식이라 정말 반가웠어요';

ProsodyAnalysisResult _recorded() {
  final words = _text.split(' ');
  var cursor = 0.0;
  final segments = <ProsodySegmentResult>[];
  for (var index = 0; index < words.length; index++) {
    final duration = 0.28 + (index % 4) * 0.13;
    segments.add(
      ProsodySegmentResult(
        text: words[index],
        start: cursor,
        end: cursor + duration,
        duration: duration,
        relativeLoudness: 0.2 + (index % 5) * 0.18,
        relativePitch: 0.3 + (index % 3) * 0.22,
        pauseAfter: index == 2 ? 0.3 : 0.04,
        emphasis: 0.25 + (index % 4) * 0.2,
      ),
    );
    cursor += duration + 0.05;
  }
  return ProsodyAnalysisResult(
    utterance: const ProsodyUtterance(
      volume: 0.6,
      pitch: 0.55,
      speed: 0.5,
      energy: 0.65,
      pause: 0.15,
      intonation: ProsodyIntonation.falling,
    ),
    segments: segments,
  );
}

void main() {
  test('a recorded utterance composes the same way live speech does', () {
    final composition = RecordedProsodyAdapter.compose(
      displayText: _text,
      prosody: _recorded(),
    );

    expect(
      composition.map((segment) => segment.text).join().trim(),
      _text,
    );

    // Nothing is left provisional: the recording is complete when it arrives.
    expect(
      composition.every(
        (segment) => segment.lifecycle != RealtimeWordLifecycle.provisional,
      ),
      isTrue,
    );

    // The same dynamic range the live stage produces.
    final scales = composition.map((segment) => segment.fontScale).toList();
    final smallest = scales.reduce((a, b) => a < b ? a : b);
    final largest = scales.reduce((a, b) => a > b ? a : b);
    expect(largest / smallest, greaterThan(1.3));
    expect(
      composition.map((segment) => segment.weightAxis).toSet().length,
      greaterThan(1),
    );
  });

  test('a recording with no measured words still renders its text', () {
    final composition = RecordedProsodyAdapter.compose(
      displayText: _text,
      prosody: ProsodyAnalysisResult(
        utterance: _recorded().utterance,
        segments: const [],
      ),
    );
    expect(composition.map((segment) => segment.text).join().trim(), _text);
  });
}
