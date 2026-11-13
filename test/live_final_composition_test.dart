import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_kinetic_planner.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_kinetic_types.dart';
import 'package:tonetype/core/models/app_language.dart';
import 'package:tonetype/features/conversation/models/conversation_state.dart';
import 'package:tonetype/features/history/models/conversation_record.dart';
import 'package:tonetype/features/conversation/widgets/realtime_kinetic_text.dart';

const _words = [
  '오늘',
  '진짜',
  '중요한',
  '이야기를',
  '하나',
  '하려고',
  '해요.',
  '잘',
  '들어주세요.',
];

List<TokenProsody> _tokens(int count) => [
  for (var index = 0; index < count; index++)
    TokenProsody(
      loudness: 0.25 + (index % 5) * 0.17,
      pitch: 0.34 + (index % 4) * 0.16,
      pitchSlope: (index.isEven ? 0.3 : -0.3),
      stretch: 0.45 + (index % 3) * 0.14,
      energy: 0.6,
    ),
];

String _flat(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

RealtimeKineticPlanner _runSession() {
  final planner = RealtimeKineticPlanner();
  for (var index = 1; index <= _words.length; index++) {
    final text = _words.take(index).join(' ');
    planner.plan(
      preview: text,
      committed: text,
      stability: 1,
      prosody: RealtimeProsodySnapshot(energy: 0.6, tokens: _tokens(index)),
    );
  }
  return planner;
}

void main() {
  test('a finished session retains typography for the whole transcript', () {
    final planner = _runSession();
    final transcript = _words.join(' ');

    final composition = planner.composition;
    expect(
      _flat(composition.map((segment) => segment.text).join()),
      _flat(transcript),
    );

    // The retained treatment must still be varied, not flattened on the way out.
    final scales = composition.map((segment) => segment.fontScale).toList();
    final smallest = scales.reduce((a, b) => a < b ? a : b);
    final largest = scales.reduce((a, b) => a > b ? a : b);
    expect(largest / smallest, greaterThan(1.3));
  });

  test('a long, bursty session still retains every word', () {
    // Google finalises in bursts, so several lines' worth of words can arrive
    // between two updates and never pass through the visible stage.
    const bursts = [
      '음, 근데 이것도 저만의 규칙을 정하고',
      '이거는 진짜 오랫동안 지키고 있는 건데 설거지는 하루를 넘기지 말자.',
      '요렇게 그 규칙을 정했어요. 그래서 어떤 습관을 만들 때 중요한 게',
      '원래 하는 일에 그 내가 습관 드리고 싶은 거를 더하면',
      '습관으로 유지하기가 쉽다라고 해요. 그래서 예를 들면 저는 어떻게 했냐면',
      '자기 전에 그 다 씻고 세수하고 이제 침대로 가기 직전에 설거지를 하자.',
    ];

    final planner = RealtimeKineticPlanner();
    var text = '';
    for (final burst in bursts) {
      text = text.isEmpty ? burst : '$text $burst';
      planner.plan(
        preview: text,
        committed: text,
        stability: 1,
        prosody: RealtimeProsodySnapshot(
          energy: 0.62,
          tokens: _tokens(RegExp(r'\S+').allMatches(text).length),
        ),
      );
    }

    final composition = planner.composition;
    expect(
      _flat(composition.map((segment) => segment.text).join()),
      _flat(text),
    );
    // Well past the two lines the stage can show at once.
    expect(composition.length, greaterThan(40));

    // The result must carry a real composition, not a flattened one.
    final result = ConversationStateModel(
      state: ConversationUiState.finalTranslation,
      finalTranslation: text,
    ).withRealtimeComposition(composition);
    expect(result.realtimeComposition, isNotEmpty);

    final scales = result.realtimeComposition
        .map((segment) => segment.fontScale)
        .toList();
    final smallest = scales.reduce((a, b) => a < b ? a : b);
    final largest = scales.reduce((a, b) => a > b ? a : b);
    expect(largest / smallest, greaterThan(1.3));
  });

  test('a saved conversation keeps its typography across a reload', () {
    final composition = _runSession().composition;
    final record = ConversationRecord.create(
      languagePair: const LanguagePair(
        source: AppLanguage.korean,
        target: AppLanguage.korean,
      ),
      context: '일상',
      originalText: _words.join(' '),
      resultText: _words.join(' '),
      kineticComposition: composition,
    );

    // Exactly what shared preferences does with the history list.
    final restored = ConversationRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );

    expect(restored.kineticComposition.length, composition.length);
    expect(
      restored.kineticComposition.map((segment) => segment.text).join(),
      composition.map((segment) => segment.text).join(),
    );
    for (var index = 0; index < composition.length; index++) {
      final saved = restored.kineticComposition[index];
      final original = composition[index];
      expect(saved.fontScale, closeTo(original.fontScale, 0.002));
      expect(saved.weightAxis, closeTo(original.weightAxis, 1));
      expect(saved.verticalBias, closeTo(original.verticalBias, 0.02));
      expect(saved.role, original.role);
      expect(saved.emphasis, closeTo(original.emphasis, 0.002));
    }

    // History holds up to 200 conversations on device, so the typography must
    // stay compact. Measured on the composition alone, since a record's fixed
    // fields would otherwise dominate a short conversation.
    final stored = record.toJson()['kinetic_composition'];
    final bytes = utf8.encode(jsonEncode(stored)).length;
    expect(bytes ~/ composition.length, lessThan(70));
  });

  test('conversations saved before this feature still load', () {
    final legacy = ConversationRecord.fromJson({
      'id': '1',
      'created_at': DateTime.utc(2026, 8, 19).toIso8601String(),
      'source_language': 'ko',
      'target_language': 'ko',
      'context': '일상',
      'original_text': '예전 기록',
      'result_text': '예전 기록',
    });
    expect(legacy.kineticComposition, isEmpty);
    expect(legacy.resultText, '예전 기록');
  });

  testWidgets('a word is never split across a line break', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final segments = _runSession().composition;

    Future<Size> renderAt(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: RealtimeKineticTranscript(segments: segments),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      return tester
          .renderObject<RenderBox>(find.byType(RealtimeKineticTranscript))
          .size;
    }

    final wide = await renderAt(350);
    final narrow = await renderAt(190);

    // Narrowing forces more line breaks, so the block must grow taller.
    expect(narrow.height, greaterThan(wide.height));

    // Every word is laid out as one indivisible box, so no break can land
    // inside one. Separators are the only text in the paragraph.
    // The outermost paragraph; every word widget contains one of its own.
    final richText = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(RealtimeKineticTranscript),
            matching: find.byType(RichText),
          ),
        )
        .first;

    List<InlineSpan> leaves(InlineSpan span) {
      if (span is TextSpan) {
        final children = span.children;
        if (children != null && children.isNotEmpty) {
          return [for (final child in children) ...leaves(child)];
        }
      }
      return [span];
    }

    final spans = leaves(richText.text);
    // Every word is one indivisible box, so no break can land inside one.
    // The only text in the paragraph is the separators between them.
    expect(spans.whereType<WidgetSpan>().length, segments.length);
    expect(
      spans.whereType<TextSpan>().where((span) => span.text == ' ').length,
      segments.length - 1,
    );
  });

  test('resetting a session clears the retained composition', () {
    final planner = _runSession()..reset();
    expect(planner.composition, isEmpty);
  });

  test('a composition that does not reproduce the transcript is dropped', () {
    final composition = _runSession().composition;
    const base = ConversationStateModel(
      state: ConversationUiState.finalTranslation,
      finalTranslation: '전혀 다른 문장입니다',
    );

    expect(base.withRealtimeComposition(composition).realtimeComposition,
        isEmpty);
    expect(
      base
          .withRealtimeComposition(const [])
          .realtimeComposition,
      isEmpty,
    );

    final matching = ConversationStateModel(
      state: ConversationUiState.finalTranslation,
      finalTranslation: _words.join(' '),
    );
    expect(
      matching.withRealtimeComposition(composition).realtimeComposition.length,
      composition.length,
    );
  });

  testWidgets('the retained composition renders without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              child: RealtimeKineticTranscript(
                segments: _runSession().composition,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final size = tester
        .renderObject<RenderBox>(find.byType(RealtimeKineticTranscript))
        .size;
    expect(size.width, lessThanOrEqualTo(350));
    expect(size.height, lessThan(420));
  });
}
