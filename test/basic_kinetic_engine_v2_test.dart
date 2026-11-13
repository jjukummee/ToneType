import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/features/conversation/kinetic/basic/basic_kinetic_planner.dart';
import 'package:tonetype/features/conversation/kinetic/basic/basic_text_kinetic_planner.dart';
import 'package:tonetype/features/conversation/kinetic/basic/phrase_segmenter.dart';
import 'package:tonetype/features/conversation/kinetic/kinetic_planner.dart';
import 'package:tonetype/features/conversation/models/kinetic_segment.dart';
import 'package:tonetype/features/conversation/models/prosody_result.dart';

void main() {
  const planner = BasicKineticPlanner();

  test('keyboard input receives an expressive language-only plan', () {
    final plan = const BasicTextKineticPlanner().plan('와! 우리 진짜 해냈어!');

    expect(plan.pattern, KineticPattern.excited);
    expect(plan.layout, KineticLayout.verticalBuild);
    expect(
      plan.segments.any((segment) => segment.motion == KineticMotion.impact),
      isTrue,
    );
    expect(plan.transcript, '와! 우리 진짜 해냈어!');
  });

  test('ordinary keyboard input still has a visible restrained ending', () {
    final plan = const BasicTextKineticPlanner().plan('오늘은 날씨가 좋아.');

    expect(
      plan.segments.any((segment) => segment.motion != KineticMotion.neutral),
      isTrue,
    );
    expect(plan.transcript, '오늘은 날씨가 좋아.');
  });

  test('a clearly emphasized spoken word becomes its own impact phrase', () {
    final plan = planner.plan(
      _input(
        '내일 말고 오늘 해 줘.',
        energy: 0.72,
        intonation: ProsodyIntonation.falling,
        emphasis: const [0.22, 0.28, 0.96, 0.34, 0.30],
      ),
    );
    final today = plan.segments.singleWhere(
      (segment) => segment.text.trim() == '오늘',
    );

    expect(today.motion, KineticMotion.impact);
    expect(today.intensity, isNot(KineticIntensity.subtle));
    expect(plan.transcript, '내일 말고 오늘 해 줘.');
  });

  test('corrected spelling remains aligned to the spoken prosody', () {
    final prosody = _prosodyFromWords(const ['안되요.'], emphasis: const [0.9]);
    final plan = planner.plan(
      KineticPlannerInput(displayText: '안 돼요.', prosody: prosody),
    );

    expect(plan.transcript, '안 돼요.');
    expect(plan.segments, isNotEmpty);
    expect(plan.segments.single.text, '안 돼요.');
  });

  test('same input always creates the same plan', () {
    final input = _input(
      '아니, 지금 당장 멈춰!',
      speed: 0.9,
      energy: 0.92,
      volume: 0.84,
      intonation: ProsodyIntonation.falling,
      emphasis: const [0.4, 0.7, 0.95, 0.86],
    );

    expect(_signature(planner.plan(input)), _signature(planner.plan(input)));
  });

  test(
    'Korean phrase rules group meaningful endings and preserve transcript',
    () {
      final input = _input('난 진짜 그런 말 한 적 없어.');
      final phrases = const PhraseSegmenter().segment(
        transcript: input.displayText,
        prosody: input.prosody,
      );

      expect(phrases.map((phrase) => phrase.text).join(), input.displayText);
      expect(phrases.any((phrase) => phrase.text.trim() == '한 적 없어.'), isTrue);
      expect(phrases.any((phrase) => phrase.text.trim() == '진짜'), isTrue);
    },
  );

  test(
    'urgent speech creates an urgent motif with restrained strong effects',
    () {
      final plan = planner.plan(
        _input(
          '아니, 지금 당장 그거 하지 마!',
          speed: 0.94,
          energy: 0.95,
          volume: 0.9,
          emphasis: const [0.4, 0.75, 0.96, 0.45, 0.86, 0.82],
        ),
      );

      expect(plan.pattern, KineticPattern.urgent);
      expect(
        plan.layout,
        anyOf(KineticLayout.verticalBuild, KineticLayout.focusCenter),
      );
      expect(
        plan.segments.where(
          (segment) => segment.intensity == KineticIntensity.strong,
        ),
        hasLength(1),
      );
      expect(
        plan.segments.any((segment) => segment.motion == KineticMotion.impact),
        isTrue,
      );
    },
  );

  test(
    'repetition uses rapid rhythm and reserves impact for the conclusion',
    () {
      final plan = planner.plan(
        _input(
          '아니, 아니, 아니, 잠깐!',
          speed: 0.88,
          energy: 0.84,
          emphasis: const [0.45, 0.48, 0.5, 0.94],
        ),
      );

      expect(plan.pattern, KineticPattern.repetition);
      expect(plan.layout, KineticLayout.staggered);
      expect(
        plan.segments
            .where((segment) => segment.motion == KineticMotion.rapid)
            .length,
        greaterThanOrEqualTo(2),
      );
      expect(plan.transcript, '아니, 아니, 아니, 잠깐!');
    },
  );

  test('meaningful pauses increase scheduled entrance delay', () {
    final plan = planner.plan(
      _input(
        '나... 사실 할 말 있어.',
        pauses: const [0.65, 0.08, 0.04, 0],
        energy: 0.42,
      ),
    );

    expect(plan.segments.length, greaterThan(1));
    expect(plan.segments[1].timing.startDelayMs, greaterThan(150));
    expect(plan.segments[1].timing.sequenceIndex, 1);
  });

  test('syllable-normalized long pronunciation becomes stretch', () {
    final plan = planner.plan(
      _input(
        '너무 좋아',
        durations: const [1.2, 0.28],
        emphasis: const [0.75, 0.4],
        speed: 0.3,
      ),
    );

    expect(
      plan.segments.any((segment) => segment.motion == KineticMotion.stretch),
      isTrue,
    );
  });

  test('rising question, low-energy doubt, and forceful speech diverge', () {
    final rising = planner.plan(
      _input(
        '진짜?',
        pitch: 0.94,
        speed: 0.78,
        energy: 0.55,
        intonation: ProsodyIntonation.rising,
      ),
    );
    final doubtful = planner.plan(
      _input(
        '진짜?',
        pitch: 0.18,
        speed: 0.22,
        energy: 0.15,
        volume: 0.2,
        intonation: ProsodyIntonation.falling,
        durations: const [1.1],
      ),
    );
    final forceful = planner.plan(
      _input(
        '진짜?',
        pitch: 0.6,
        speed: 0.55,
        energy: 0.96,
        volume: 0.96,
        intonation: ProsodyIntonation.flat,
        emphasis: const [0.98],
      ),
    );

    expect(rising.segments.single.motion, KineticMotion.rise);
    expect(
      _signature(rising),
      isNot(anyOf(_signature(doubtful), _signature(forceful))),
    );
    expect({
      _signature(rising),
      _signature(doubtful),
      _signature(forceful),
    }, hasLength(3));
  });

  test(
    'whisper vocabulary needs quiet prosody and produces whisper motion',
    () {
      final plan = planner.plan(
        _input(
          '쉿 아무한테도 말하지 마.',
          volume: 0.12,
          energy: 0.14,
          speed: 0.38,
          emphasis: const [0.3, 0.45, 0.5, 0.42],
        ),
      );

      expect(plan.pattern, KineticPattern.whisper);
      expect(
        plan.segments.any((segment) => segment.motion == KineticMotion.whisper),
        isTrue,
      );
      expect(plan.layout, KineticLayout.quietSpace);
    },
  );

  test('falling negative ending settles instead of rising', () {
    final plan = planner.plan(
      _input(
        '아니. 난 안 해.',
        intonation: ProsodyIntonation.falling,
        energy: 0.68,
        emphasis: const [0.65, 0.35, 0.72, 0.86],
      ),
    );

    expect(plan.pattern, KineticPattern.firm);
    expect(plan.segments.last.motion, KineticMotion.settle);
    expect(plan.layout, KineticLayout.focusEnd);
  });

  test('empty text and missing word features degrade gracefully', () {
    final emptyProsody = _prosodyFromWords(const []);
    final empty = planner.plan(
      KineticPlannerInput(displayText: '', prosody: emptyProsody),
    );
    final unaligned = planner.plan(
      KineticPlannerInput(displayText: '괜찮아.', prosody: emptyProsody),
    );

    expect(empty.segments, isEmpty);
    expect(unaligned.transcript, '괜찮아.');
    expect(unaligned.segments, hasLength(1));
  });

  test('nullable pitch and a very short utterance remain valid', () {
    final prosody = ProsodyAnalysisResult(
      utterance: const ProsodyUtterance(
        volume: 0.5,
        pitch: null,
        speed: null,
        energy: 0.5,
        pause: 0,
        intonation: ProsodyIntonation.unknown,
      ),
      segments: const [
        ProsodySegmentResult(
          text: '응',
          start: 0,
          end: 0.2,
          duration: 0.2,
          relativeLoudness: 0.5,
          relativePitch: null,
          pauseAfter: 0,
          emphasis: 0.4,
        ),
      ],
    );
    final plan = planner.plan(
      KineticPlannerInput(displayText: '응', prosody: prosody),
    );

    expect(plan.transcript, '응');
    expect(plan.segments.single.salience, inInclusiveRange(0, 1));
  });

  test('balanced Korean dataset remains deterministic and lossless', () {
    const dataset = [
      '오늘 학교 끝나고 뭐 해?',
      '난 진짜 안 했어.',
      '뭐? 진짜라고?!',
      '잠깐! 지금 멈춰!',
      '음... 나 잘 모르겠는데...',
      '괜찮아... 천천히 해.',
      '아무한테도 말하지 마.',
      '와! 우리 진짜 해냈어!',
      '아니. 난 안 해.',
      '너무 좋아.',
      '아니 아니 아니 잠깐!',
      '정말?',
      '그럴 리 없어.',
      '지금 당장 와.',
      '혹시 조금만 기다려줄래?',
      '쉿 비밀이야.',
      '완전 최고야!',
      '반드시 끝낼 거야.',
      '그냥 그런 것 같아.',
      '하지 마.',
      '빨리 빨리!',
      '어... 그게 아니라...',
      '조심해!',
      '난 그런 말 한 적 없어.',
      '할 수 없어.',
      '보고 싶어.',
      '오늘은 날씨가 좋아.',
      '대박, 정말 멋지다!',
      '천천히 해도 돼.',
      '무조건 해낼 거야.',
      '안 돼!',
      '글쎄, 아마 괜찮을 거야.',
      '제일 중요한 이야기야.',
      '음... 잠깐만.',
      '진짜 진짜 고마워.',
      '끝.',
    ];

    for (final transcript in dataset) {
      final input = _input(transcript);
      final first = planner.plan(input);
      final second = planner.plan(input);
      expect(first.transcript, transcript, reason: transcript);
      expect(_signature(first), _signature(second), reason: transcript);
      expect(
        first.segments
            .where((segment) => segment.intensity == KineticIntensity.strong)
            .length,
        lessThanOrEqualTo(first.segments.length <= 4 ? 1 : 2),
        reason: transcript,
      );
    }
  });

  test(
    'planner stays within the local millisecond-scale performance budget',
    () {
      final input = _input('아니, 지금 당장 그거 하지 마!', speed: 0.9, energy: 0.9);
      final stopwatch = Stopwatch()..start();
      for (var index = 0; index < 300; index++) {
        planner.plan(input);
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMicroseconds / 300, lessThan(20000));
    },
  );
}

KineticPlannerInput _input(
  String transcript, {
  double volume = 0.62,
  double pitch = 0.55,
  double speed = 0.5,
  double energy = 0.58,
  ProsodyIntonation intonation = ProsodyIntonation.flat,
  List<double>? emphasis,
  List<double>? durations,
  List<double>? pauses,
}) {
  final words = transcript
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  return KineticPlannerInput(
    displayText: transcript,
    prosody: _prosodyFromWords(
      words,
      volume: volume,
      pitch: pitch,
      speed: speed,
      energy: energy,
      intonation: intonation,
      emphasis: emphasis,
      durations: durations,
      pauses: pauses,
    ),
    debug: true,
  );
}

ProsodyAnalysisResult _prosodyFromWords(
  List<String> words, {
  double volume = 0.62,
  double pitch = 0.55,
  double speed = 0.5,
  double energy = 0.58,
  ProsodyIntonation intonation = ProsodyIntonation.flat,
  List<double>? emphasis,
  List<double>? durations,
  List<double>? pauses,
}) {
  var cursor = 0.0;
  final segments = <ProsodySegmentResult>[];
  for (var index = 0; index < words.length; index++) {
    final duration = durations != null && index < durations.length
        ? durations[index]
        : 0.24 + (index % 3) * 0.04;
    final pause = pauses != null && index < pauses.length
        ? pauses[index]
        : 0.04;
    segments.add(
      ProsodySegmentResult(
        text: words[index],
        start: cursor,
        end: cursor + duration,
        duration: duration,
        relativeLoudness: (0.38 + (index % 4) * 0.16).clamp(0, 1),
        relativePitch: (0.32 + (index % 3) * 0.22).clamp(0, 1),
        pauseAfter: pause,
        emphasis: emphasis != null && index < emphasis.length
            ? emphasis[index]
            : (0.3 + (index % 4) * 0.13).clamp(0, 1),
      ),
    );
    cursor += duration + pause;
  }
  return ProsodyAnalysisResult(
    utterance: ProsodyUtterance(
      volume: volume,
      pitch: pitch,
      speed: speed,
      energy: energy,
      pause: pauses == null || pauses.isEmpty
          ? 0.08
          : pauses.reduce((a, b) => a + b) / pauses.length,
      intonation: intonation,
    ),
    segments: segments,
  );
}

String _signature(KineticPlan plan) => [
  plan.pattern.name,
  plan.layout.name,
  for (final segment in plan.segments)
    '${segment.text}|${segment.motion.name}|${segment.intensity.name}|'
        '${segment.salience.toStringAsFixed(5)}|${segment.timing.startDelayMs}|'
        '${segment.timing.durationMs}',
].join('::');
