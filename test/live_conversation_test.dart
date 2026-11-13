import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/core/models/app_language.dart';
import 'package:tonetype/core/state/app_controller.dart';
import 'package:tonetype/core/state/app_scope.dart';
import 'package:tonetype/core/theme/app_theme.dart';
import 'package:tonetype/features/conversation/data/live_conversation_api_client.dart';
import 'package:tonetype/features/conversation/data/live_speech_input_service.dart';
import 'package:tonetype/features/conversation/data/prosody_api_client.dart';
import 'package:tonetype/features/conversation/data/speech_input_service.dart';
import 'package:tonetype/features/conversation/models/prosody_result.dart';
import 'package:tonetype/features/conversation/models/speech_capture_mode.dart';
import 'package:tonetype/features/conversation/screens/conversation_screen.dart';
import 'package:tonetype/features/conversation/widgets/microphone_control.dart';
import 'package:tonetype/features/conversation/widgets/realtime_kinetic_text.dart';

void main() {
  testWidgets('live mode shows corrected interim text and saves final result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController.memory();
    final source = _FakeLiveConversationSource();
    final input = _FakeLiveSpeechInputService();
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ConversationScreen(
            liveConversationSource: source,
            liveSpeechInputService: input,
          ),
        ),
      ),
    );

    await tester.tap(find.text('실시간'));
    await tester.pump();
    expect(controller.speechCaptureMode, SpeechCaptureMode.live);
    expect(find.text('말하는 동안 문장을 바로 번역해드릴게요.'), findsOneWidget);

    await tester.tap(find.byType(MicrophoneControl));
    await tester.pump();
    expect(find.text('실시간 번역 중'), findsOneWidget);
    expect(source.receivedAudio, isNotEmpty);
    expect(find.byKey(const ValueKey('one-shot-voice-glyph')), findsNothing);
    expect(find.text('듣는 대로 옮기고 있어요…'), findsOneWidget);

    source.emit(
      const LiveConversationUpdate(
        text: '안되요 <0xEC><0xB0><0x9D><0xEC><0xB0><0x9D>한데 지금은',
        committedText: '안되요 <0xEC><0xB0><0x9D><0xEC><0xB0><0x9D>한데',
        isFinal: true,
        stability: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.textContaining('안', findRichText: true), findsOneWidget);
    expect(find.textContaining('돼요', findRichText: true), findsOneWidget);
    expect(find.textContaining('찝찝', findRichText: true), findsWidgets);
    expect(find.textContaining('<0x', findRichText: true), findsNothing);
    expect(find.text('지금은'), findsOneWidget);

    await tester.tap(find.byType(MicrophoneControl));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('돼요.', findRichText: true), findsWidgets);
    expect(find.text('키네틱 결과'), findsOneWidget);
    expect(controller.conversationHistory, hasLength(1));
    expect(controller.conversationHistory.single.resultText, '안 돼요.');
    expect(input.isListening, isFalse);

    await tester.tap(find.text('말투 분석'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('문장별 말투 지도'), findsOneWidget);
    expect(find.text('문장별 핵심'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a long live transcript stays inside its frame without scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController.memory()
      ..setSpeechCaptureMode(SpeechCaptureMode.live);
    final source = _FakeLiveConversationSource();
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ConversationScreen(
            liveConversationSource: source,
            liveSpeechInputService: _FakeLiveSpeechInputService(),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(MicrophoneControl));
    await tester.pump();
    final longText = List.generate(
      28,
      (index) => '정확도를 유지하는 아주 긴 연속 문장 ${index + 1}입니다.',
    ).join(' ');
    source.emit(
      LiveConversationUpdate(
        text: longText,
        committedText: longText,
        isFinal: true,
        stability: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final microphone = find.byType(MicrophoneControl);
    final stage = find.byType(RealtimeKineticText);

    // The live stage is a fixed window on what is being said now. There is
    // nothing to scroll and nothing to chase.
    expect(
      find.descendant(of: stage, matching: find.byType(Scrollable)),
      findsNothing,
    );
    expect(find.byType(Scrollbar), findsNothing);
    // Words leaving the top of the frame fade out rather than being cut.
    expect(find.byType(ShaderMask), findsWidgets);
    expect(find.text('한 번'), findsNothing);
    expect(find.text('실시간'), findsNothing);
    expect(tester.getSize(microphone).height, lessThanOrEqualTo(64));
    expect(
      tester.getBottomRight(stage).dy,
      lessThanOrEqualTo(tester.getTopLeft(microphone).dy),
    );

    // A burst of speech can add far more than a line at once. The frame must
    // absorb it without overflowing or pushing the controls off screen.
    final burst = List.generate(
      24,
      (index) => '뒤이어 도착한 긴 문장 ${index + 1}입니다.',
    ).join(' ');
    source.emit(
      LiveConversationUpdate(
        text: burst,
        committedText: burst,
        isFinal: true,
        stability: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomRight(find.byType(RealtimeKineticText)).dy,
      lessThanOrEqualTo(tester.getTopLeft(microphone).dy),
    );

    await tester.tap(microphone);
    await tester.pump(const Duration(milliseconds: 400));
    final finalScroll = find.byKey(const ValueKey('final-result-scroll'));
    expect(finalScroll, findsOneWidget);
    expect(find.byType(MicrophoneControl), findsNothing);
    expect(
      tester.getBottomRight(finalScroll).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const ValueKey('result-control-dock'))).dy,
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('websocket client frames PCM and parses a completed stream', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final chunkSizes = <int>[];
    final started = Completer<Map<String, dynamic>>();
    final serverDone = Completer<void>();
    var sentInterim = false;
    final serverSubscription = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      await for (final message in socket) {
        if (message is String) {
          final json = jsonDecode(message) as Map<String, dynamic>;
          if (json['type'] == 'start') {
            started.complete(json);
            socket.add(jsonEncode(const {'type': 'ready'}));
          } else if (json['type'] == 'stop') {
            socket.add(
              jsonEncode({
                'type': 'complete',
                'transcript': '안 돼요.',
                'detected_language': 'ko-KR',
                'prosody': _prosodyJson(),
              }),
            );
            await socket.close();
            if (!serverDone.isCompleted) serverDone.complete();
          }
        } else if (message is List<int>) {
          chunkSizes.add(message.length);
          if (!sentInterim) {
            sentInterim = true;
            socket.add(
              jsonEncode(const {
                'type': 'transcript',
                'text': '<0xEC><0xB0><0x9D><0xEC><0xB0><0x9D>해요',
                'committed_text': '',
                'is_final': false,
                'stability': 0.42,
              }),
            );
          }
        }
      }
    });
    addTearDown(() async {
      await serverSubscription.cancel();
      await server.close(force: true);
    });

    final client = LiveConversationApiClient(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    final updates = await client.start(
      languagePair: const LanguagePair(
        source: AppLanguage.korean,
        target: AppLanguage.korean,
      ),
      conversationContext: '일상',
      dictionary: const ['ToneType'],
    );
    final interim = updates.first;
    client.addAudio(Uint8List(30_000));
    expect((await interim).text, '찝찝해요');
    final completed = await client.finish();
    await serverDone.future;

    final start = await started.future;
    expect(start['dictionary'], ['ToneType']);
    expect(chunkSizes, [12 * 1024, 12 * 1024, 5424]);
    expect(completed.transcript, '안 돼요.');
    expect(completed.prosody.segments, hasLength(1));
  });

  test('websocket rejection returns an error instead of hanging', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverSubscription = server.listen((request) async {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    });
    addTearDown(() async {
      await serverSubscription.cancel();
      await server.close(force: true);
    });

    final client = LiveConversationApiClient(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    final start = client
        .start(
          languagePair: const LanguagePair(
            source: AppLanguage.korean,
            target: AppLanguage.korean,
          ),
          conversationContext: '일상',
          dictionary: const [],
        )
        .timeout(const Duration(seconds: 2));

    await expectLater(
      start,
      throwsA(
        isA<ProsodyApiException>().having(
          (error) => error.code,
          'code',
          'network_error',
        ),
      ),
    );
    await client.close();
  });
}

class _FakeLiveSpeechInputService implements LiveSpeechInputService {
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<SpeechAvailability> initialize() async => SpeechAvailability.ready;

  @override
  Future<void> start({
    required ValueChanged<Uint8List> onAudioChunk,
    required ValueChanged<double> onSoundLevel,
    required ValueChanged<Object> onError,
  }) async {
    _listening = true;
    onSoundLevel(-18);
    onAudioChunk(Uint8List(640));
  }

  @override
  Future<void> stop() async => _listening = false;

  @override
  Future<void> cancel() => stop();

  @override
  Future<void> dispose() => cancel();
}

class _FakeLiveConversationSource implements LiveConversationSource {
  final StreamController<LiveConversationUpdate> _updates =
      StreamController<LiveConversationUpdate>();
  final List<int> receivedAudio = [];

  void emit(LiveConversationUpdate update) => _updates.add(update);

  @override
  Future<Stream<LiveConversationUpdate>> start({
    required LanguagePair languagePair,
    required String conversationContext,
    required List<String> dictionary,
  }) async => _updates.stream;

  @override
  void addAudio(Uint8List chunk) => receivedAudio.add(chunk.length);

  @override
  Future<LiveConversationFinal> finish() async => LiveConversationFinal(
    transcript: '안되요.',
    detectedLanguage: 'ko-KR',
    prosody: ProsodyAnalysisResult.fromJson(_prosodyJson()),
  );

  @override
  Future<void> cancel() async {}

  @override
  Future<void> close() async {
    if (!_updates.isClosed) await _updates.close();
  }
}

Map<String, dynamic> _prosodyJson() => {
  'utterance': {
    'volume': 0.7,
    'pitch': 0.55,
    'speed': 0.6,
    'energy': 0.72,
    'pause': 0.1,
    'intonation': 'falling',
  },
  'segments': [
    {
      'text': '안 돼요.',
      'start': 0.0,
      'end': 0.8,
      'duration': 0.8,
      'relative_loudness': 0.8,
      'relative_pitch': 0.6,
      'pause_after': 0.0,
      'emphasis': 0.7,
    },
  ],
};
