import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_environment.dart';
import '../models/prosody_result.dart';

abstract interface class ProsodyAnalysisSource {
  Future<ProsodyAnalysisResult> analyzeAudio({
    required String audioPath,
    required String language,
    List<ProsodyWordTimestamp> timestamps = const [],
    bool debug = false,
  });
}

class ProsodyApiException implements Exception {
  const ProsodyApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ProsodyApiException($code): $message';
}

class ProsodyApiClient implements ProsodyAnalysisSource {
  ProsodyApiClient({required Uri baseUri, http.Client? client})
    : _baseUri = baseUri,
      _client = client ?? http.Client();

  factory ProsodyApiClient.fromEnvironment({http.Client? client}) {
    return ProsodyApiClient(
      baseUri: AppEnvironment.apiBaseUri(),
      client: client,
    );
  }

  final Uri _baseUri;
  final http.Client _client;

  @override
  Future<ProsodyAnalysisResult> analyzeAudio({
    required String audioPath,
    required String language,
    List<ProsodyWordTimestamp> timestamps = const [],
    bool debug = false,
  }) async {
    final endpoint = _baseUri
        .resolve('/api/prosody/analyze')
        .replace(queryParameters: debug ? const {'debug': 'true'} : null);
    final request = http.MultipartRequest('POST', endpoint)
      ..fields['language'] = language
      ..files.add(await http.MultipartFile.fromPath('audio', audioPath));
    if (timestamps.isNotEmpty) {
      request.fields['timestamps'] = jsonEncode(
        timestamps.map((timestamp) => timestamp.toJson()).toList(),
      );
    }

    http.StreamedResponse streamed;
    try {
      streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
    } on Object {
      throw ProsodyApiException(
        code: 'network_error',
        message: '말투 분석 서버에 연결하지 못했어요.',
      );
    }

    final response = await http.Response.fromStream(streamed);
    final decoded = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final detail = error is Map<String, dynamic> ? error : const {};
      throw ProsodyApiException(
        code: detail['code'] as String? ?? 'analysis_failed',
        message: detail['message'] as String? ?? '오디오를 분석하지 못했어요.',
        statusCode: response.statusCode,
      );
    }
    try {
      return ProsodyAnalysisResult.fromJson(decoded);
    } on FormatException {
      throw ProsodyApiException(
        code: 'invalid_response',
        message: '말투 분석 결과 형식이 올바르지 않아요.',
        statusCode: response.statusCode,
      );
    }
  }

  void close() => _client.close();
}

Map<String, dynamic> _decodeObject(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}
