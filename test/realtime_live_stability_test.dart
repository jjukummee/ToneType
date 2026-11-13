import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_kinetic_planner.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_kinetic_types.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_token_prosody.dart';

List<TokenProsody> _tokens(int count) => [
  for (var index = 0; index < count; index++)
    TokenProsody(
      loudness: 0.3 + ((index * 7) % 11) / 16,
      pitch: 0.35 + ((index * 5) % 9) / 15,
      energy: 0.6,
    ),
];

void main() {
  test('an interim result that shrinks does not wipe the composition', () {
    final planner = RealtimeKineticPlanner();
    const full =
        '음 근데 이것도 저만의 규칙을 정하고 이거는 진짜 오랫동안 지키고 있는 건데 '
        '설거지는 하루를 넘기지 말자 요렇게 그 규칙을 정했어요';

    final grown = planner.plan(
      preview: full,
      committed: '',
      stability: 0.7,
      prosody: RealtimeProsodySnapshot(
        energy: 0.6,
        tokens: _tokens(RegExp(r'\S+').allMatches(full).length),
      ),
    );
    expect(grown.committed.length, greaterThan(15));

    // Google's interim text routinely drops back before growing again.
    final shrunk = planner.plan(
      preview: '음 근데 이것도',
      committed: '',
      stability: 0.4,
      prosody: RealtimeProsodySnapshot(energy: 0.6, tokens: _tokens(3)),
    );

    expect(
      shrunk.committed.length,
      greaterThanOrEqualTo(grown.committed.length),
      reason: 'words already settled must not vanish and come back',
    );
    expect(shrunk.currentLine, grown.currentLine);
  });

  test('words already measured keep their typography when the tail is not', () {
    // The aligner can lag the recogniser by a word or two, especially right
    // after a rewrite. Discarding a whole line for that left the end of long
    // speech completely flat.
    const text = '오늘 진짜 좋았고 내일도 그럴 것 같아';
    final plan = RealtimeKineticPlanner().plan(
      preview: text,
      committed: text,
      stability: 1,
      prosody: RealtimeProsodySnapshot(energy: 0.6, tokens: _tokens(4)),
    );

    final scales = plan.committed.map((segment) => segment.fontScale).toSet();
    expect(plan.committed.length, greaterThan(4));
    expect(
      scales.length,
      greaterThan(1),
      reason: 'the measured words must still differ from one another',
    );
  });

  test('growth resumes immediately after the recogniser backtracks', () {
    final planner = RealtimeKineticPlanner();
    const long = '하나 둘 셋 넷 다섯 여섯 일곱 여덟 아홉 열 열하나 열둘 열셋 열넷 열다섯 열여섯';
    int words(String value) => RegExp(r'\S+').allMatches(value).length;

    final grown = planner.plan(
      preview: long,
      committed: '',
      stability: 0.6,
      prosody: RealtimeProsodySnapshot(
        energy: 0.6,
        tokens: _tokens(words(long)),
      ),
    );

    // A large backtrack must not remove what is already on screen …
    final backtracked = planner.plan(
      preview: '하나 둘 셋 넷',
      committed: '',
      stability: 0.5,
      prosody: RealtimeProsodySnapshot(energy: 0.6, tokens: _tokens(4)),
    );
    expect(backtracked.committed.length, grown.committed.length);

    // … and speech that continues afterwards must appear straight away, not
    // crawl back one word at a time while the stage catches up.
    const continued = '$long 이어서 계속 말하는 중입니다 그리고 더';
    final resumed = planner.plan(
      preview: continued,
      committed: '',
      stability: 0.6,
      prosody: RealtimeProsodySnapshot(
        energy: 0.6,
        tokens: _tokens(words(continued)),
      ),
    );
    expect(
      resumed.committed.length,
      greaterThan(grown.committed.length + 3),
    );
  });

  test('a genuine rewrite still replaces what it contradicts', () {
    final planner = RealtimeKineticPlanner();
    planner.plan(
      preview: '오늘은 정말 좋은 날씨',
      committed: '',
      stability: 1,
      prosody: RealtimeProsodySnapshot(energy: 0.6, tokens: _tokens(4)),
    );
    final revised = planner.plan(
      preview: '오늘은 정말 흐린 하늘이야 그렇지',
      committed: '',
      stability: 1,
      prosody: RealtimeProsodySnapshot(energy: 0.6, tokens: _tokens(5)),
    );

    expect(
      revised.currentLine.replaceAll(RegExp(r'\s+'), ' ').trim(),
      startsWith('오늘은 정말 흐린'),
    );
    expect(revised.currentLine.contains('좋은'), isFalse);
  });

  test('re-measured words keep their audio after a rewrite', () {
    // Voiced speech followed by a moment of silence.
    final frames = <ProsodyFrame>[
      for (var index = 0; index < 50; index++)
        ProsodyFrame(timeMs: (index + 1) * 20, rms: 0.2, pitch: 0.5),
      for (var index = 50; index < 60; index++)
        ProsodyFrame(timeMs: (index + 1) * 20, rms: 0, pitch: double.nan),
    ];
    const audioMs = 1200.0;

    final aligner = RealtimeTokenProsodyAligner();
    aligner.sync(text: '가 나', frames: frames, audioMs: audioMs);

    // The recogniser replaces the tail. Without rewinding to where the
    // discarded words began, the replacements are measured against no audio at
    // all and every one of them collapses to a neutral default.
    final revised = aligner.sync(
      text: '가 다 라',
      frames: frames,
      audioMs: audioMs,
    );

    expect(revised, hasLength(3));
    expect(
      revised.last.pauseAfter,
      greaterThan(0),
      reason: 'the trailing silence is only visible if the window was restored',
    );
  });
}
