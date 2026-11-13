import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/app.dart';
import 'package:tonetype/core/state/app_controller.dart';
import 'package:tonetype/core/state/app_scope.dart';
import 'package:tonetype/core/theme/app_theme.dart';
import 'package:tonetype/features/conversation/data/conversation_audio_api_client.dart';
import 'package:tonetype/features/conversation/data/speech_input_service.dart';
import 'package:tonetype/features/conversation/audio/voice_visualization_analyzer.dart';
import 'package:tonetype/features/conversation/models/prosody_result.dart';
import 'package:tonetype/features/conversation/models/kinetic_segment.dart';
import 'package:tonetype/features/conversation/screens/conversation_screen.dart';
import 'package:tonetype/features/conversation/widgets/microphone_control.dart';

void main() {
  testWidgets('ToneType starts with the brand splash', (tester) async {
    await tester.pumpWidget(ToneTypeApp(controller: AppController.memory()));

    expect(find.text('ToneType', findRichText: true), findsOneWidget);
    expect(find.text('말의 뜻을 넘어, 말투까지.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('onboarding reaches the conversation screen', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController.memory()..continueAsGuest();
    await tester.pumpWidget(ToneTypeApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text('번역은 됐지만,\n느낌까지 전달됐을까요?'), findsOneWidget);

    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    expect(find.text('말투도 번역할 수 있어요.'), findsOneWidget);

    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();

    expect(find.text('말한 뒤 멈추면 말투까지 분석해드릴게요.'), findsOneWidget);
    expect(find.text('일상'), findsOneWidget);
    expect(find.text('번역'), findsOneWidget);
    expect(find.text('대화 기록'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('main tabs open directly without language or context setup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController.memory()
      ..continueAsGuest()
      ..completeOnboarding();
    await tester.pumpWidget(ToneTypeApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text('말한 뒤 멈추면 말투까지 분석해드릴게요.'), findsOneWidget);
    expect(find.text('어떤 언어로 대화할까요?'), findsNothing);
    expect(find.text('어떤 대화를 시작하나요?'), findsNothing);

    await tester.tap(find.text('대화 기록'));
    await tester.pumpAndSettle();
    expect(find.text('아직 저장된 대화가 없어요.'), findsOneWidget);

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(find.text('기본 번역 언어'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('recorded speech progresses from listening to analyzed result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final speech = _FakeSpeechInputService();
    final controller = AppController.memory();
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ConversationScreen(
            speechInputService: speech,
            audioAnalysisSource: const _FakeAudioAnalysisSource(),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'현재 번역 언어 한국어 → 한국어')),
      findsOneWidget,
    );
    expect(find.text('일상'), findsOneWidget);
    await tester.tap(find.text('일상'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('여행'));
    await tester.pumpAndSettle();
    expect(find.text('여행'), findsOneWidget);

    await tester.tap(find.text('기본'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 하이브리드'));
    await tester.pumpAndSettle();
    expect(controller.kineticGenerationMode, KineticGenerationMode.hybrid);
    expect(find.text('AI'), findsOneWidget);

    expect(find.bySemanticsLabel('번역 시작하기'), findsOneWidget);
    await tester.tap(find.byType(MicrophoneControl));
    await tester.pump();
    expect(find.text('듣고 있어요'), findsOneWidget);
    expect(find.bySemanticsLabel('번역 멈추기'), findsOneWidget);
    expect(find.byKey(const ValueKey('one-shot-voice-glyph')), findsOneWidget);
    expect(find.byKey(const ValueKey('one-shot-pitch-marker')), findsOneWidget);

    await tester.tap(find.byType(MicrophoneControl));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('오늘이라고'), findsOneWidget);
    expect(find.text('AI 하이브리드'), findsOneWidget);
    expect(find.text('키네틱 결과'), findsOneWidget);
    // The result now replays the composition that was measured, so there is no
    // entrance animation to trigger again.
    expect(find.bySemanticsLabel('모션 다시 보기'), findsNothing);
    expect(find.text('새 번역'), findsOneWidget);
    expect(find.bySemanticsLabel('대화 종료'), findsNothing);
    expect(controller.conversationHistory, hasLength(1));
    expect(controller.conversationHistory.single.originalText, contains('오늘'));
    await tester.tap(find.text('말투 분석'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('단어별 말투 해부'), findsOneWidget);
    expect(find.text('핵심 단어 상세'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeSpeechInputService implements SpeechInputService {
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<SpeechAvailability> initialize() async => SpeechAvailability.ready;

  @override
  Future<void> start({
    required ValueChanged<VoiceVisualSignal> onVisualSignal,
  }) async {
    _listening = true;
    onVisualSignal(
      const VoiceVisualSignal(
        amplitude: 0.72,
        pitch: 0.8,
        pitchConfidence: 0.9,
      ),
    );
  }

  @override
  Future<String?> stop() async {
    _listening = false;
    return '/tmp/fake-tonetype.wav';
  }

  @override
  Future<void> cancel() async => _listening = false;

  @override
  Future<void> dispose() => cancel();
}

class _FakeAudioAnalysisSource implements ConversationAudioAnalysisSource {
  const _FakeAudioAnalysisSource();

  @override
  Future<ConversationAudioAnalysis> analyzeAudio({
    required String audioPath,
    required dynamic languagePair,
    String conversationContext = '일상',
    KineticGenerationMode kineticMode = KineticGenerationMode.basic,
    bool debug = false,
  }) async {
    return const ConversationAudioAnalysis(
      transcript: '내일 말고 오늘이라고 했어.',
      detectedLanguage: 'ko-KR',
      prosody: ProsodyAnalysisResult(
        utterance: ProsodyUtterance(
          volume: 0.7,
          pitch: 0.55,
          speed: 0.6,
          energy: 0.72,
          pause: 0.1,
          intonation: ProsodyIntonation.falling,
        ),
        segments: [
          ProsodySegmentResult(
            text: '내일',
            start: 0,
            end: 0.2,
            duration: 0.2,
            relativeLoudness: 0.3,
            relativePitch: 0.4,
            pauseAfter: 0.04,
            emphasis: 0.2,
          ),
          ProsodySegmentResult(
            text: '말고',
            start: 0.24,
            end: 0.42,
            duration: 0.18,
            relativeLoudness: 0.4,
            relativePitch: 0.4,
            pauseAfter: 0.04,
            emphasis: 0.3,
          ),
          ProsodySegmentResult(
            text: '오늘이라고',
            start: 0.46,
            end: 0.72,
            duration: 0.26,
            relativeLoudness: 0.95,
            relativePitch: 0.8,
            pauseAfter: 0.04,
            emphasis: 0.9,
          ),
          ProsodySegmentResult(
            text: '했어',
            start: 0.76,
            end: 0.96,
            duration: 0.2,
            relativeLoudness: 0.5,
            relativePitch: 0.4,
            pauseAfter: 0,
            emphasis: 0.35,
          ),
        ],
      ),
      kineticPlan: KineticPlan(
        mode: KineticGenerationMode.hybrid,
        pattern: KineticPattern.strongEmphasis,
        layout: KineticLayout.focusEnd,
        segments: [
          KineticSegment(text: '내일 '),
          KineticSegment(text: '말고 '),
          KineticSegment(
            text: '오늘이라고',
            motion: KineticMotion.impact,
            intensity: KineticIntensity.strong,
            salience: 0.9,
          ),
          KineticSegment(text: ' 했어.'),
        ],
      ),
      kineticSource: KineticResultSource.hybrid,
      kineticInterpretation: '대조되는 핵심 표현을 강조합니다.',
    );
  }
}
