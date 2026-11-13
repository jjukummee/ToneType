import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/config/app_environment.dart';
import '../../../core/models/app_language.dart';
import '../../../core/text/text_encoding_repair.dart';
import '../models/prosody_result.dart';
import 'prosody_api_client.dart';

class LiveConversationUpdate {
  const LiveConversationUpdate({
    required this.text,
    required this.committedText,
    required this.isFinal,
    required this.stability,
  });

  final String text;
  final String committedText;
  final bool isFinal;
  final double stability;
}

class LiveConversationFinal {
  const LiveConversationFinal({
    required this.transcript,
    required this.detectedLanguage,
    required this.prosody,
  });

  final String transcript;
  final String detectedLanguage;
  final ProsodyAnalysisResult prosody;
}

abstract interface class LiveConversationSource {
  Future<Stream<LiveConversationUpdate>> start({
    required LanguagePair languagePair,
    required String conversationContext,
    required List<String> dictionary,
  });

  void addAudio(Uint8List chunk);
  Future<LiveConversationFinal> finish();
  Future<void> cancel();
  Future<void> close();
}

class LiveConversationApiClient implements LiveConversationSource {
  LiveConversationApiClient({required Uri baseUri}) : _baseUri = baseUri;

  factory LiveConversationApiClient.fromEnvironment() =>
      LiveConversationApiClient(baseUri: AppEnvironment.apiBaseUri());

  static const _maximumChunkBytes = 12 * 1024;
  final Uri _baseUri;

  WebSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  StreamController<LiveConversationUpdate>? _updates;
  Completer<void>? _ready;
  Completer<LiveConversationFinal>? _final;
  bool _finishing = false;

  @override
  Future<Stream<LiveConversationUpdate>> start({
    required LanguagePair languagePair,
    required String conversationContext,
    required List<String> dictionary,
  }) async {
    if (_socket != null) {
      throw StateError('A live conversation is already active.');
    }
    final endpoint = _baseUri
        .resolve('/api/conversations/stream')
        .replace(scheme: _baseUri.scheme == 'https' ? 'wss' : 'ws');
    // The server handshake finishes before this stream is returned to the UI.
    // A broadcast controller can be closed safely if that handshake fails
    // before the first listener is attached.
    final updates = StreamController<LiveConversationUpdate>.broadcast();
    final ready = Completer<void>();
    final completed = Completer<LiveConversationFinal>();
    _updates = updates;
    _ready = ready;
    _final = completed;
    _finishing = false;

    try {
      final socket = await WebSocket.connect(
        endpoint.toString(),
      ).timeout(const Duration(seconds: 6));
      _socket = socket;
      _subscription = socket.listen(
        _handleMessage,
        onError: (Object error, StackTrace stackTrace) =>
            _fail(_networkException(), stackTrace),
        onDone: _handleDone,
        cancelOnError: false,
      );
      socket.add(
        jsonEncode({
          'type': 'start',
          'source_language': _bcp47(languagePair.source),
          'target_language': _bcp47(languagePair.target),
          'conversation_context': conversationContext,
          'dictionary': dictionary,
        }),
      );
      await ready.future.timeout(const Duration(seconds: 6));
      return updates.stream;
    } on ProsodyApiException {
      await cancel();
      rethrow;
    } on Object {
      await cancel();
      throw _networkException();
    }
  }

  @override
  void addAudio(Uint8List chunk) {
    final socket = _socket;
    if (socket == null || _finishing || chunk.isEmpty) return;
    for (var offset = 0; offset < chunk.length; offset += _maximumChunkBytes) {
      final end = (offset + _maximumChunkBytes).clamp(0, chunk.length);
      socket.add(Uint8List.sublistView(chunk, offset, end));
    }
  }

  @override
  Future<LiveConversationFinal> finish() async {
    final socket = _socket;
    final completed = _final;
    if (socket == null || completed == null) {
      throw const ProsodyApiException(
        code: 'stream_not_started',
        message: '실시간 음성 인식이 시작되지 않았어요.',
      );
    }
    if (!_finishing) {
      _finishing = true;
      socket.add(jsonEncode(const {'type': 'stop'}));
    }
    try {
      return await completed.future.timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const ProsodyApiException(
        code: 'stream_timeout',
        message: '최종 음성 분석 시간이 오래 걸리고 있어요. 다시 시도해주세요.',
      );
    } finally {
      await close();
    }
  }

  void _handleMessage(Object? message) {
    if (message is! String) return;
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return;
      switch (decoded['type']) {
        case 'ready':
          if (!(_ready?.isCompleted ?? true)) _ready!.complete();
        case 'transcript':
          final preview = TextEncodingRepair.restoreUtf8ByteMarkers(
            decoded['text'] as String? ?? '',
          );
          final committed = TextEncodingRepair.restoreUtf8ByteMarkers(
            decoded['committed_text'] as String? ?? '',
          );
          _updates?.add(
            LiveConversationUpdate(
              text: preview,
              committedText: committed,
              isFinal: decoded['is_final'] as bool? ?? false,
              stability: (decoded['stability'] as num?)?.toDouble() ?? 0,
            ),
          );
        case 'complete':
          final prosody = decoded['prosody'];
          if (prosody is! Map<String, dynamic>) {
            throw const FormatException('Missing prosody result.');
          }
          if (!(_final?.isCompleted ?? true)) {
            _final!.complete(
              LiveConversationFinal(
                transcript: TextEncodingRepair.restoreUtf8ByteMarkers(
                  decoded['transcript'] as String? ?? '',
                ),
                detectedLanguage: decoded['detected_language'] as String? ?? '',
                prosody: ProsodyAnalysisResult.fromJson(prosody),
              ),
            );
          }
        case 'error':
          final raw = decoded['error'];
          final error = raw is Map<String, dynamic> ? raw : const {};
          _fail(
            ProsodyApiException(
              code: error['code'] as String? ?? 'stream_failed',
              message: _localizedLiveError(
                error['code'] as String?,
                error['message'] as String?,
              ),
            ),
          );
      }
    } on FormatException catch (error, stackTrace) {
      _fail(
        const ProsodyApiException(
          code: 'invalid_response',
          message: '실시간 음성 분석 결과 형식이 올바르지 않아요.',
        ),
        stackTrace,
      );
    }
  }

  void _handleDone() {
    if (!(_final?.isCompleted ?? true)) {
      _final!.completeError(_networkException());
    }
    if (!(_ready?.isCompleted ?? true)) {
      _ready!.completeError(_networkException());
    }
    unawaited(_updates?.close());
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (!(_ready?.isCompleted ?? true)) {
      _ready!.completeError(error, stackTrace);
    }
    if (!(_final?.isCompleted ?? true)) {
      _final!.completeError(error, stackTrace);
    }
    _updates?.addError(error, stackTrace);
  }

  @override
  Future<void> cancel() async {
    _finishing = true;
    final socket = _socket;
    final subscription = _subscription;
    final updates = _updates;
    _socket = null;
    _subscription = null;
    _updates = null;
    await subscription?.cancel().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    await socket
        ?.close(WebSocketStatus.normalClosure, 'cancelled')
        .timeout(const Duration(seconds: 2), onTimeout: () {});
    if (updates != null && !updates.isClosed) await updates.close();
    _clearSession();
  }

  @override
  Future<void> close() async {
    final socket = _socket;
    final subscription = _subscription;
    final updates = _updates;
    _socket = null;
    _subscription = null;
    _updates = null;
    await subscription?.cancel().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    await socket
        ?.close(WebSocketStatus.normalClosure)
        .timeout(const Duration(seconds: 2), onTimeout: () {});
    if (updates != null && !updates.isClosed) await updates.close();
    _clearSession();
  }

  void _clearSession() {
    _updates = null;
    _ready = null;
    _final = null;
    _finishing = false;
  }
}

String _bcp47(AppLanguage language) => switch (language) {
  AppLanguage.korean => 'ko-KR',
  AppLanguage.english => 'en-US',
};

ProsodyApiException _networkException() => const ProsodyApiException(
  code: 'network_error',
  message: '실시간 음성 분석 서버에 연결하지 못했어요.',
);

String _localizedLiveError(String? code, String? fallback) => switch (code) {
  'speech_not_recognized' => '말소리를 인식하지 못했어요. 조금 더 가까이에서 말해주세요.',
  'speech_credentials_missing' => '음성 인식 서버 인증이 필요해요.',
  'speech_configuration_missing' => '음성 인식 서버 설정이 필요해요.',
  'speech_service_unavailable' => 'Google 음성 인식에 연결하지 못했어요. 잠시 후 다시 시도해주세요.',
  'silence_only' => '말소리가 들리지 않았어요. 다시 말해주세요.',
  _ => fallback ?? '실시간 음성 인식을 계속하지 못했어요.',
};
