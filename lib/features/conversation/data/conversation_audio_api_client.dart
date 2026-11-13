import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_environment.dart';
import '../../../core/models/app_language.dart';
import '../models/prosody_result.dart';
import '../models/kinetic_segment.dart';
import 'prosody_api_client.dart';

class ConversationAudioAnalysis {
  const ConversationAudioAnalysis({
    required this.transcript,
    required this.detectedLanguage,
    required this.prosody,
    this.kineticPlan,
    this.kineticSource = KineticResultSource.basic,
    this.kineticInterpretation,
  });

  final String transcript;
  final String detectedLanguage;
  final ProsodyAnalysisResult prosody;
  final KineticPlan? kineticPlan;
  final KineticResultSource kineticSource;
  final String? kineticInterpretation;
}

abstract interface class ConversationAudioAnalysisSource {
  Future<ConversationAudioAnalysis> analyzeAudio({
    required String audioPath,
    required LanguagePair languagePair,
    String conversationContext = '일상',
    KineticGenerationMode kineticMode = KineticGenerationMode.basic,
    bool debug = false,
  });
}

class ConversationAudioApiClient implements ConversationAudioAnalysisSource {
  ConversationAudioApiClient({required Uri baseUri, http.Client? client})
    : _baseUri = baseUri,
      _client = client ?? http.Client();

  factory ConversationAudioApiClient.fromEnvironment({http.Client? client}) {
    return ConversationAudioApiClient(
      baseUri: AppEnvironment.apiBaseUri(),
      client: client,
    );
  }

  final Uri _baseUri;
  final http.Client _client;

  @override
  Future<ConversationAudioAnalysis> analyzeAudio({
    required String audioPath,
    required LanguagePair languagePair,
    String conversationContext = '일상',
    KineticGenerationMode kineticMode = KineticGenerationMode.basic,
    bool debug = false,
  }) async {
    final endpoint = _baseUri
        .resolve('/api/conversations/analyze')
        .replace(queryParameters: debug ? const {'debug': 'true'} : null);
    final request = http.MultipartRequest('POST', endpoint)
      ..fields['source_language'] = _bcp47(languagePair.source)
      ..fields['target_language'] = _bcp47(languagePair.target)
      ..fields['conversation_context'] = conversationContext
      ..fields['kinetic_mode'] = kineticMode.apiValue
      ..files.add(await http.MultipartFile.fromPath('audio', audioPath));

    http.StreamedResponse streamed;
    try {
      streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
    } on Object {
      throw const ProsodyApiException(
        code: 'network_error',
        message: '음성 분석 서버에 연결하지 못했어요.',
      );
    }

    final response = await http.Response.fromStream(streamed);
    final decoded = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final detail = error is Map<String, dynamic> ? error : const {};
      throw ProsodyApiException(
        code: detail['code'] as String? ?? 'analysis_failed',
        message: _localizedError(
          detail['code'] as String?,
          detail['message'] as String?,
        ),
        statusCode: response.statusCode,
      );
    }

    final prosodyJson = decoded['prosody'];
    if (prosodyJson is! Map<String, dynamic>) {
      throw ProsodyApiException(
        code: 'invalid_response',
        message: '음성 분석 결과 형식이 올바르지 않아요.',
        statusCode: response.statusCode,
      );
    }
    final transcript = decoded['transcript'] as String? ?? '';
    final kineticJson = decoded['kinetic'];
    final hybridText = kineticJson is Map<String, dynamic>
        ? _kineticText(kineticJson['segments'])
        : '';
    final usedHybrid =
        kineticMode == KineticGenerationMode.hybrid &&
        hybridText == transcript &&
        transcript.isNotEmpty;
    return ConversationAudioAnalysis(
      transcript: transcript,
      detectedLanguage: decoded['detected_language'] as String? ?? '',
      prosody: ProsodyAnalysisResult.fromJson(prosodyJson),
      kineticPlan: usedHybrid
          ? KineticPlan.hybridFromJson(
              transcript: transcript,
              json: kineticJson,
            )
          : null,
      kineticSource: usedHybrid
          ? KineticResultSource.hybrid
          : kineticMode == KineticGenerationMode.hybrid
          ? KineticResultSource.basicFallback
          : KineticResultSource.basic,
      kineticInterpretation: kineticJson is Map<String, dynamic>
          ? (kineticJson['interpretation'] as String?)?.trim()
          : null,
    );
  }

  void close() => _client.close();
}

String _kineticText(Object? value) {
  if (value is! List) return '';
  return value
      .whereType<Map<String, dynamic>>()
      .map((segment) => segment['text'] as String? ?? '')
      .join();
}

String _bcp47(AppLanguage language) => switch (language) {
  AppLanguage.korean => 'ko-KR',
  AppLanguage.english => 'en-US',
};

Map<String, dynamic> _decodeObject(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}

String _localizedError(String? code, String? fallback) => switch (code) {
  'translation_not_configured' => '다른 언어로 번역하는 서버가 아직 연결되지 않았어요.',
  'speech_credentials_missing' => '음성 인식 서버 인증이 필요해요.',
  'speech_configuration_missing' => '음성 인식 서버 설정이 필요해요.',
  'speech_not_recognized' => '말소리를 인식하지 못했어요. 조금 더 가까이에서 말해주세요.',
  'speech_service_unavailable' => 'Google 음성 인식에 연결하지 못했어요. 잠시 후 다시 시도해주세요.',
  'silence_only' => '말소리가 들리지 않았어요. 다시 말해주세요.',
  _ => fallback ?? '오디오를 분석하지 못했어요.',
};
