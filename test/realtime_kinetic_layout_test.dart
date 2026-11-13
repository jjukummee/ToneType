import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_kinetic_planner.dart';
import 'package:tonetype/features/conversation/kinetic/realtime/realtime_kinetic_types.dart';
import 'package:tonetype/features/conversation/widgets/realtime_kinetic_text.dart';

RealtimeKineticPlan _loudPlan() {
  const text = '지금 당장 그만하고 여기서 나랑 같이 이야기 좀 하자 진짜로';
  return RealtimeKineticPlanner().plan(
    preview: '$text 제발',
    committed: text,
    stability: 0.6,
    prosody: RealtimeProsodySnapshot(
      energy: 0.95,
      relativeLoudness: 0.7,
      speedDeviation: 0.5,
      tokens: [
        for (var index = 0; index < 11; index++)
          TokenProsody(
            loudness: index == 4 ? 0.99 : 0.62 + (index % 3) * 0.08,
            pitch: index.isEven ? 0.78 : 0.34,
            stretch: index == 4 ? 0.9 : 0.5,
            energy: 0.9,
          ),
      ],
    ),
  );
}

Future<Size> _render(
  WidgetTester tester, {
  required RealtimeKineticPlan plan,
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 350,
            child: MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: RealtimeKineticText(plan: plan),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull);
  return tester
      .renderObject<RenderBox>(find.byType(RealtimeKineticText))
      .size;
}

void main() {
  testWidgets('a loud long line stays inside the live stage', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final size = await _render(tester, plan: _loudPlan());

    expect(size.width, lessThanOrEqualTo(350));
    // The dynamic range is allowed to be wide, but the stage must not grow
    // into the controls below it.
    expect(size.height, lessThan(320));
  });

  testWidgets('reduced motion still renders the measured composition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final size = await _render(
      tester,
      plan: _loudPlan(),
      reduceMotion: true,
    );

    expect(size.height, lessThan(320));
    expect(find.byType(RealtimeKineticText), findsOneWidget);
  });
}
