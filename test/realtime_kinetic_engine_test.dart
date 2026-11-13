import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/features/conversation/kinetic/basic/basic_text_kinetic_planner.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_kinetic_planner.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_kinetic_types.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_prosody_tracker.dart';
import 'package:tonetype/features/conversation/models/kinetic_segment.dart';

void main() {
  group('RealtimeKineticPlanner', () {
    test('keeps interim words provisional and limits attention', () {
      final plan = RealtimeKineticPlanner().plan(
        preview: '아니 지금 당장 거기서 멈춰 잠깐',
        committed: '아니 지금 당장 거기서 멈춰',
        stability: 0.46,
        prosody: const RealtimeProsodySnapshot(
          relativeLoudness: 0.8,
          pitchDeviation: 0.4,
          pitchSlope: 0.35,
          energy: 0.9,
          speedDeviation: 0.3,
        ),
      );

      expect(plan.provisional, isNotEmpty);
      expect(
        plan.provisional.every(
          (segment) =>
              segment.lifecycle == RealtimeWordLifecycle.provisional &&
              segment.intensity == RealtimeKineticIntensity.subtle,
        ),
        isTrue,
      );
      expect(
        plan.committed
            .where(
              (segment) => segment.intensity == RealtimeKineticIntensity.strong,
            )
            .length,
        lessThanOrEqualTo(1),
      );
      expect(
        plan.committed
            .where(
              (segment) => segment.intensity == RealtimeKineticIntensity.medium,
            )
            .length,
        lessThanOrEqualTo(2),
      );
    });

    test('maps combined prosody to restrained deterministic motion', () {
      final planner = RealtimeKineticPlanner();
      const prosody = RealtimeProsodySnapshot(
        relativeLoudness: 0.78,
        pitchDeviation: 0.55,
        pitchSlope: 0.42,
        energy: 0.86,
        speedDeviation: 0.15,
      );
      final first = planner.plan(
        preview: '진짜?',
        committed: '진짜?',
        stability: 1,
        prosody: prosody,
      );
      final second = planner.plan(
        preview: '진짜?',
        committed: '진짜?',
        stability: 1,
        prosody: prosody,
      );

      expect(identical(first, second), isTrue);
      expect(first.committed.single.intensity, RealtimeKineticIntensity.strong);
      expect(
        first.committed.single.motion,
        anyOf(RealtimeKineticMotion.pulse, RealtimeKineticMotion.lift),
      );
      expect(first.committed.single.verticalBias.abs(), lessThanOrEqualTo(13));
    });

    test(
      'supports repetition, drawn-out speech, pause and falling endings',
      () {
        final repetition = RealtimeKineticPlanner().plan(
          preview: '아니 아니 아니 잠깐!',
          committed: '아니 아니 아니 잠깐!',
          stability: 1,
          prosody: const RealtimeProsodySnapshot(
            speedDeviation: 0.8,
            energy: 0.7,
          ),
        );
        expect(
          repetition.committed.where(
            (segment) => segment.motion == RealtimeKineticMotion.rush,
          ),
          isNotEmpty,
        );

        final stretched = RealtimeKineticPlanner().plan(
          preview: '너~~~무 좋다.',
          committed: '너~~~무 좋다.',
          stability: 1,
          prosody: const RealtimeProsodySnapshot(durationAnomaly: 1),
        );
        expect(stretched.committed.first.motion, RealtimeKineticMotion.stretch);

        final pause = RealtimeKineticPlanner().plan(
          preview: '나... 사실',
          committed: '나...',
          stability: 0.6,
          prosody: const RealtimeProsodySnapshot(pause: 0.9, energy: 0.3),
        );
        expect(pause.committed.single.motion, RealtimeKineticMotion.hold);

        final falling = RealtimeKineticPlanner().plan(
          preview: '됐어.',
          committed: '됐어.',
          stability: 1,
          prosody: const RealtimeProsodySnapshot(
            pitchDeviation: -0.5,
            pitchSlope: -0.5,
            energy: 0.55,
          ),
        );
        expect(falling.committed.single.motion, RealtimeKineticMotion.settle);
      },
    );

    test('keeps a bounded two-line stage and archives older speech', () {
      final plan = RealtimeKineticPlanner().plan(
        preview: '첫 문장입니다. 두 번째 문장입니다. 지금 말하는 문장입니다.',
        committed: '첫 문장입니다. 두 번째 문장입니다. 지금 말하는 문장입니다.',
        stability: 1,
        prosody: const RealtimeProsodySnapshot(),
      );

      // Recent lines keep their typography; only older speech is archived.
      expect(plan.archivedText, isEmpty);
      expect(
        plan.currentLine.replaceAll(RegExp(r'\s+'), ' ').trim(),
        '첫 문장입니다. 두 번째 문장입니다. 지금 말하는 문장입니다.',
      );
    });

    test('plans a live update within a sub-millisecond average budget', () {
      final planner = RealtimeKineticPlanner();
      final stopwatch = Stopwatch()..start();
      for (var index = 0; index < 300; index++) {
        planner.plan(
          preview: '실시간 반응 속도를 확인하는 문장 $index',
          committed: '실시간 반응 속도를 확인하는 문장',
          stability: 0.7,
          prosody: RealtimeProsodySnapshot(
            relativeLoudness: (index % 8) / 8,
            pitchSlope: ((index % 5) - 2) / 4,
            energy: 0.6,
          ),
        );
      }
      stopwatch.stop();
      expect(stopwatch.elapsedMicroseconds / 300, lessThan(1000));
    });

    test('per-word measurement decides emphasis inside one line', () {
      final plan = RealtimeKineticPlanner().plan(
        preview: '오늘 진짜 좋았어',
        committed: '오늘 진짜 좋았어',
        stability: 1,
        prosody: const RealtimeProsodySnapshot(
          energy: 0.6,
          tokens: [
            TokenProsody(loudness: 0.22, pitch: 0.48),
            TokenProsody(loudness: 0.95, pitch: 0.86, stretch: 0.72),
            TokenProsody(loudness: 0.30, pitch: 0.44),
          ],
        ),
      );

      final peaks = plan.committed.where(
        (segment) => segment.role == RealtimeEmphasisRole.peak,
      );
      expect(peaks.length, 1);
      expect(peaks.single.text.trim(), '진짜');
      expect(plan.dominantWord, '진짜');
      // The loud word must be visibly larger, not marginally so.
      expect(
        peaks.single.fontScale,
        greaterThan(plan.committed.first.fontScale * 1.2),
      );
      expect(peaks.single.weightAxis, greaterThan(700));
    });

    test('pitch contour lifts high tones and stays bounded', () {
      final plan = RealtimeKineticPlanner().plan(
        preview: '높게 낮게 높게',
        committed: '높게 낮게 높게',
        stability: 1,
        prosody: const RealtimeProsodySnapshot(
          tokens: [
            TokenProsody(loudness: 0.5, pitch: 0.92),
            TokenProsody(loudness: 0.5, pitch: 0.10),
            TokenProsody(loudness: 0.5, pitch: 0.88),
          ],
        ),
      );

      final offsets = [
        for (final segment in plan.committed) segment.verticalBias,
      ];
      expect(offsets.first, lessThan(offsets[1]));
      expect(offsets.last, lessThan(offsets[1]));
      expect(offsets.every((value) => value.abs() <= 13), isTrue);
    });

    test('a uniformly loud line stays calm instead of shouting', () {
      final plan = RealtimeKineticPlanner().plan(
        preview: '전부 다 크게 말한 아주 시끄러운 문장이야',
        committed: '전부 다 크게 말한 아주 시끄러운 문장이야',
        stability: 1,
        prosody: RealtimeProsodySnapshot(
          energy: 0.9,
          tokens: List.filled(
            7,
            const TokenProsody(loudness: 0.96, pitch: 0.9, stretch: 0.8),
          ),
        ),
      );

      // Nothing genuinely stands out when every word is equally loud, so the
      // line carries its delivery through the shared baseline instead.
      expect(
        plan.committed
            .where((segment) => segment.role == RealtimeEmphasisRole.peak)
            .length,
        lessThanOrEqualTo(1),
      );
      expect(
        plan.committed
            .where((segment) => segment.role == RealtimeEmphasisRole.secondary)
            .length,
        lessThanOrEqualTo(2),
      );
      // Raised words are never side by side.
      for (var index = 1; index < plan.committed.length; index++) {
        final left = plan.committed[index - 1].role;
        final right = plan.committed[index].role;
        expect(
          left != RealtimeEmphasisRole.calm &&
              right != RealtimeEmphasisRole.calm,
          isFalse,
        );
      }
      // The movement budget keeps a busy line from inflating overall.
      final demand = plan.committed.fold<double>(
        0,
        (sum, segment) => sum + (segment.fontScale - 1).abs(),
      );
      expect(demand, lessThanOrEqualTo(1.07));
    });

    test('committed words keep their measurement when new words arrive', () {
      final planner = RealtimeKineticPlanner();
      const first = TokenProsody(loudness: 0.9, pitch: 0.8);
      const second = TokenProsody(loudness: 0.2, pitch: 0.45);
      final before = planner.plan(
        preview: '강하게 약하게',
        committed: '강하게 약하게',
        stability: 1,
        prosody: const RealtimeProsodySnapshot(tokens: [first, second]),
      );
      final beforeScale = before.committed.first.fontScale;

      final after = planner.plan(
        preview: '강하게 약하게 그리고',
        committed: '강하게 약하게 그리고',
        stability: 1,
        prosody: const RealtimeProsodySnapshot(
          tokens: [first, second, TokenProsody(loudness: 0.25, pitch: 0.5)],
        ),
      );

      // The word's own measurement is frozen; only the line-level baseline may
      // drift slightly as the sentence grows.
      expect(after.committed.first.role, before.committed.first.role);
      expect(after.committed.first.fontScale, closeTo(beforeScale, 0.06));
    });

    test('every word takes its own size and the spread stays legible', () {
      final plan = RealtimeKineticPlanner().plan(
        preview: '형이 있었대 근데 꼴등만 하던 그 형이',
        committed: '형이 있었대 근데 꼴등만 하던 그 형이',
        stability: 1,
        prosody: const RealtimeProsodySnapshot(
          energy: 0.72,
          tokens: [
            TokenProsody(loudness: 0.72, pitch: 0.62),
            TokenProsody(loudness: 0.30, pitch: 0.44),
            TokenProsody(loudness: 0.88, pitch: 0.78, stretch: 0.62),
            TokenProsody(loudness: 0.64, pitch: 0.58),
            TokenProsody(loudness: 0.48, pitch: 0.50),
            TokenProsody(loudness: 0.34, pitch: 0.46),
            TokenProsody(loudness: 0.70, pitch: 0.66),
          ],
        ),
      );

      final scales = [
        for (final segment in plan.committed) segment.fontScale,
      ];
      final smallest = scales.reduce((a, b) => a < b ? a : b);
      final largest = scales.reduce((a, b) => a > b ? a : b);

      // The composition must not collapse into one spike over a flat field.
      expect(largest / smallest, greaterThan(1.5));
      expect(scales.toSet().length, greaterThanOrEqualTo(scales.length - 1));

      // Size and weight always agree about which word was stressed.
      final loudest = plan.committed.reduce(
        (a, b) => a.fontScale > b.fontScale ? a : b,
      );
      expect(
        plan.committed.every(
          (segment) =>
              segment == loudest || segment.weightAxis <= loudest.weightAxis,
        ),
        isTrue,
      );
    });

    test('delivery level moves the whole line, not just one word', () {
      List<RealtimeKineticSegment> render({
        required double loudness,
        required double energy,
      }) =>
          RealtimeKineticPlanner()
              .plan(
                preview: '이렇게 말하고 있어',
                committed: '이렇게 말하고 있어',
                stability: 1,
                prosody: RealtimeProsodySnapshot(
                  energy: energy,
                  tokens: [
                    TokenProsody(loudness: loudness, pitch: 0.5),
                    TokenProsody(loudness: loudness + 0.03, pitch: 0.52),
                    TokenProsody(loudness: loudness - 0.02, pitch: 0.48),
                  ],
                ),
              )
              .committed;

      final hushed = render(loudness: 0.14, energy: 0.25);
      final raised = render(loudness: 0.92, energy: 0.95);

      double meanWeight(List<RealtimeKineticSegment> line) =>
          line.fold<double>(0, (sum, s) => sum + s.weightAxis) / line.length;
      double meanScale(List<RealtimeKineticSegment> line) =>
          line.fold<double>(0, (sum, s) => sum + s.fontScale) / line.length;

      // A whisper and a shout must be distinguishable at a glance even when
      // neither has a standout word.
      expect(meanWeight(raised) - meanWeight(hushed), greaterThan(280));
      expect(meanScale(raised) - meanScale(hushed), greaterThan(0.12));
    });

    test('typography appears before the recogniser finalises anything', () {
      // Google's streaming recogniser can hold final results for many seconds.
      // Styling only finalised text leaves an entire spoken paragraph grey.
      const preview = '음, 근데 이것도 저만의 규칙을 정하고 이거는 진짜 오랫동안 지키고 있는 건데';
      final plan = RealtimeKineticPlanner().plan(
        preview: preview,
        committed: '',
        stability: 0.6,
        prosody: const RealtimeProsodySnapshot(energy: 0.6),
      );

      expect(plan.committed, isNotEmpty);
      // Only the newest few words stay unsettled.
      expect(plan.provisional.length, lessThanOrEqualTo(3));
      expect(
        plan.committed.every(
          (segment) => segment.lifecycle != RealtimeWordLifecycle.provisional,
        ),
        isTrue,
      );
      // Nothing is lost between the settled line and the draft tail.
      expect(
        '${plan.currentLine} ${plan.provisionalLine}'
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
        preview.replaceAll(RegExp(r'\s+'), ' ').trim(),
      );
    });

    test('draft words are already shaped, and recent lines stay styled', () {
      final planner = RealtimeKineticPlanner();
      const preview =
          '음 근데 이것도 저만의 규칙을 정하고 이거는 진짜 오랫동안 지키고 있는 건데 설거지는 하루를 넘기지 말자. '
          '요렇게 그 규칙을 정했어요. 그래서 어떤 습관을 만들 때 중요한 게 원래 하는 일에 더하면 쉽다고 해요.';
      final plan = planner.plan(
        preview: preview,
        // The worst case: the recogniser has finalised nothing at all.
        committed: '',
        stability: 0.6,
        prosody: RealtimeProsodySnapshot(
          energy: 0.62,
          tokens: [
            for (var index = 0;
                index < RegExp(r'\S+').allMatches(preview).length;
                index++)
              TokenProsody(
                loudness: 0.28 + ((index * 7) % 11) / 15,
                pitch: 0.32 + ((index * 5) % 9) / 14,
                stretch: 0.45 + ((index * 3) % 5) / 12,
                energy: 0.62,
              ),
          ],
        ),
      );

      // Only the newest words remain unsettled.
      expect(plan.provisional.length, lessThanOrEqualTo(2));
      // Several lines' worth of words keep their treatment on screen.
      expect(plan.committed.length, greaterThan(12));

      // Draft words carry their own measurements rather than a flat placeholder.
      final draftScales = plan.provisional
          .map((segment) => segment.fontScale)
          .toSet();
      expect(draftScales.length, plan.provisional.length);
      expect(
        plan.provisional.every((segment) => segment.emphasis <= 0.6),
        isTrue,
        reason: 'a word still being revised must not take the accent colour',
      );
    });

    test('a long session bounds its grey history and widens the stage', () {
      final planner = RealtimeKineticPlanner();
      var text = '';
      for (var index = 1; index <= 14; index++) {
        text = text.isEmpty
            ? '$index번째로 말한 꽤 긴 문장이고 내용도 제법 이어집니다.'
            : '$text $index번째로 말한 꽤 긴 문장이고 내용도 제법 이어집니다.';
        planner.plan(
          preview: text,
          committed: text,
          stability: 1,
          prosody: RealtimeProsodySnapshot(
            energy: 0.6,
            tokens: [
              for (var i = 0;
                  i < RegExp(r'\S+').allMatches(text).length;
                  i++)
                TokenProsody(
                  loudness: 0.3 + ((i * 7) % 11) / 16,
                  pitch: 0.35 + ((i * 5) % 9) / 15,
                  energy: 0.6,
                ),
            ],
          ),
        );
      }
      final plan = planner.plan(
        preview: text,
        committed: text,
        stability: 1,
        prosody: RealtimeProsodySnapshot(
          energy: 0.6,
          tokens: [
            for (var i = 0; i < RegExp(r'\S+').allMatches(text).length; i++)
              const TokenProsody(loudness: 0.5, pitch: 0.5, energy: 0.6),
          ],
        ),
      );

      // The grey history stays inside about three rendered lines, dropping the
      // oldest speech rather than the most recent.
      expect(plan.archivedText.length, lessThanOrEqualTo(72));
      expect(plan.archivedText, startsWith('…'));
      // What survives is the most recent history, not the oldest.
      final kept = plan.archivedText.replaceFirst('… ', '');
      expect(text.contains(kept), isTrue);
      expect(text.startsWith(kept), isFalse);

      // Several lines keep their typography instead of one.
      expect(plan.committed.length, greaterThan(30));

      // Nothing is lost: the final result still covers the whole utterance.
      expect(
        planner.composition
            .map((segment) => segment.text)
            .join()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
        text.replaceAll(RegExp(r'\s+'), ' ').trim(),
      );
    });

    test('does not mutate or replace the Basic planner result', () {
      const basic = BasicTextKineticPlanner();
      final before = basic.plan('오늘은 정말 괜찮아.');
      RealtimeKineticPlanner().plan(
        preview: '오늘은 정말 괜찮아.',
        committed: '오늘은 정말 괜찮아.',
        stability: 1,
        prosody: const RealtimeProsodySnapshot(relativeLoudness: 1, energy: 1),
      );
      final after = basic.plan('오늘은 정말 괜찮아.');

      expect(_basicSignature(after), _basicSignature(before));
    });
  });

  test('RealtimeProsodyTracker produces bounded speaker-relative signals', () {
    var now = DateTime(2026, 8, 19, 12);
    final tracker = RealtimeProsodyTracker(clock: () => now);
    tracker.addSoundLevel(-24);
    for (var index = 0; index < 6; index++) {
      tracker.addAudio(_sineChunk(frequency: 180));
      now = now.add(const Duration(milliseconds: 80));
    }
    tracker.addSoundLevel(-12);
    final snapshot = tracker.snapshot(preview: '진짜 좋아', committed: '진짜');

    expect(snapshot.relativeLoudness, inInclusiveRange(-1, 1));
    expect(snapshot.pitchDeviation, inInclusiveRange(-1, 1));
    expect(snapshot.pitchSlope, inInclusiveRange(-1, 1));
    expect(snapshot.energy, inInclusiveRange(0, 1));
  });
}

Uint8List _sineChunk({required double frequency}) {
  const samples = 640;
  final bytes = Uint8List(samples * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < samples; index++) {
    final value = math.sin(2 * math.pi * frequency * index / 16000) * 0.4;
    data.setInt16(index * 2, (value * 32767).round(), Endian.little);
  }
  return bytes;
}

String _basicSignature(KineticPlan plan) => [
  plan.pattern,
  plan.layout,
  for (final segment in plan.segments)
    '${segment.text}:${segment.motion}:${segment.intensity}:${segment.salience}',
].join('|');
