import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tonetype/core/models/app_language.dart';
import 'package:tonetype/features/conversation/data/conversation_audio_api_client.dart';
import 'package:tonetype/features/conversation/data/prosody_api_client.dart';
import 'package:tonetype/features/conversation/kinetic/prosody_kinetic_planner.dart';
import 'package:tonetype/features/conversation/models/kinetic_segment.dart';
import 'package:tonetype/features/conversation/models/prosody_result.dart';

void main() {
  const response = {
    'utterance': {
      'volume': 0.72,
      'pitch': 0.58,
      'speed': 0.64,
      'energy': 0.77,
      'pause': 0.2,
      'intonation': 'falling',
    },
    'segments': [
      {
        'text': '내일',
        'start': 0.0,
        'end': 0.3,
        'duration': 0.3,
        'relative_loudness': 0.3,
        'relative_pitch': 0.2,
        'pause_after': 0.05,
        'emphasis': 0.18,
      },
      {
        'text': '오늘',
        'start': 0.5,
        'end': 0.9,
        'duration': 0.4,
        'relative_loudness': 0.95,
        'relative_pitch': 0.86,
        'pause_after': 0.0,
        'emphasis': 0.94,
      },
    ],
  };

  test('parses normalized prosody response', () {
    final result = ProsodyAnalysisResult.fromJson(response);

    expect(result.utterance.intonation, ProsodyIntonation.falling);
    expect(result.segments.last.text, '오늘');
    expect(result.segments.last.emphasis, 0.94);
  });

  test('maps aligned emphasis into existing kinetic tokens', () {
    final result = ProsodyAnalysisResult.fromJson(response);
    final segments = const ProsodyKineticPlanner().plan(
      displayText: '내일 말고 오늘이라고 했어.',
      prosody: result,
    );
    final dominant = segments.reduce(
      (current, next) => next.salience > current.salience ? next : current,
    );

    expect(dominant.motion, isNot(KineticMotion.neutral));
    expect(dominant.intensity, isNot(KineticIntensity.subtle));
    expect(segments.map((segment) => segment.text).join(), '내일 말고 오늘이라고 했어.');
  });

  test('keeps translation neutral when source words cannot be aligned', () {
    final result = ProsodyAnalysisResult.fromJson(response);
    final segments = const ProsodyKineticPlanner().plan(
      displayText: 'I said today, not tomorrow.',
      prosody: result,
    );

    expect(segments, hasLength(1));
    expect(segments.single.motion, KineticMotion.neutral);
  });

  test('multipart client returns typed result and sends timestamps', () async {
    final mock = _CapturingClient(jsonEncode(response));
    final directory = await Directory.systemTemp.createTemp('tonetype_test_');
    addTearDown(() => directory.delete(recursive: true));
    final audio = File('${directory.path}/sample.wav');
    await audio.writeAsBytes([82, 73, 70, 70]);
    final client = ProsodyApiClient(
      baseUri: Uri.parse('http://127.0.0.1:8000'),
      client: mock,
    );

    final result = await client.analyzeAudio(
      audioPath: audio.path,
      language: 'ko-KR',
      timestamps: const [ProsodyWordTimestamp(text: '오늘', start: 0, end: 0.4)],
    );

    expect(mock.captured.method, 'POST');
    expect(mock.captured.url.path, '/api/prosody/analyze');
    expect(result.segments.last.emphasis, 0.94);
    client.close();
  });

  test(
    'conversation client uploads language pair and parses analysis',
    () async {
      final body = jsonEncode({
        'transcript': '오늘이라고 했어.',
        'detected_language': 'ko-KR',
        'words': const [],
        'prosody': response,
        'kinetic': {
          'source': 'google_gemini',
          'model': 'gemini-test',
          'interpretation': '핵심 표현을 강조합니다.',
          'segments': [
            {'text': '오늘이라고 했어.', 'motion': 'impact', 'intensity': 'strong'},
          ],
        },
        'kinetic_fallback': false,
      });
      final mock = _CapturingClient(body);
      final directory = await Directory.systemTemp.createTemp(
        'tonetype_audio_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final audio = File('${directory.path}/sample.wav');
      await audio.writeAsBytes([82, 73, 70, 70]);
      final client = ConversationAudioApiClient(
        baseUri: Uri.parse('http://127.0.0.1:8000'),
        client: mock,
      );

      final result = await client.analyzeAudio(
        audioPath: audio.path,
        languagePair: const LanguagePair(
          source: AppLanguage.korean,
          target: AppLanguage.korean,
        ),
        conversationContext: '일상',
        kineticMode: KineticGenerationMode.hybrid,
      );

      final request = mock.captured as http.MultipartRequest;
      expect(request.url.path, '/api/conversations/analyze');
      expect(request.fields['source_language'], 'ko-KR');
      expect(request.fields['target_language'], 'ko-KR');
      expect(request.fields['conversation_context'], '일상');
      expect(request.fields['kinetic_mode'], 'hybrid');
      expect(result.transcript, '오늘이라고 했어.');
      expect(result.prosody.segments.last.emphasis, 0.94);
      expect(result.kineticSource, KineticResultSource.hybrid);
      expect(result.kineticPlan!.segments.single.motion, KineticMotion.impact);
      client.close();
    },
  );
}

class _CapturingClient extends http.BaseClient {
  _CapturingClient(this.responseBody);

  final String responseBody;
  late http.BaseRequest captured;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    captured = request;
    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}
