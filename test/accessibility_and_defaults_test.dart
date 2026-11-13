import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/app.dart';
import 'package:tonetype/core/models/app_language.dart';
import 'package:tonetype/core/state/app_controller.dart';
import 'package:tonetype/features/conversation/models/kinetic_segment.dart';
import 'package:tonetype/features/conversation/models/speech_capture_mode.dart';

void main() {
  test('new installs default to Korean to Korean', () {
    final controller = AppController.memory();

    expect(controller.sourceLanguage, AppLanguage.korean);
    expect(controller.targetLanguage, AppLanguage.korean);
    expect(controller.languagePair.label, '한국어 → 한국어');
    expect(controller.defaultContext, '일상');
    expect(controller.kineticGenerationMode, KineticGenerationMode.basic);
    expect(controller.speechCaptureMode, SpeechCaptureMode.single);
  });

  testWidgets('login remains usable at the largest app text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController.memory()..setTextScale(1.6);
    await tester.pumpWidget(ToneTypeApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text('ToneType', findRichText: true), findsOneWidget);
    expect(find.text('로그인 없이 시작하기'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('guest browse action exposes an accessibility label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(ToneTypeApp(controller: AppController.memory()));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('로그인 없이 시작하기'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
