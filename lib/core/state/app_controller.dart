import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_language.dart';
import '../config/app_environment.dart';
import '../../features/history/models/conversation_record.dart';
import '../../features/conversation/models/kinetic_segment.dart';
import '../../features/conversation/models/speech_capture_mode.dart';

enum SessionMode { none, guest, signedIn }

class AppController extends ChangeNotifier {
  AppController._(this._preferences) {
    _restore();
  }

  factory AppController.memory() => AppController._(null);

  static Future<AppController> create() async {
    final preferences = await SharedPreferences.getInstance();
    return AppController._(preferences);
  }

  final SharedPreferences? _preferences;

  SessionMode _sessionMode = SessionMode.none;
  bool _onboardingComplete = false;
  AppLanguage _sourceLanguage = AppLanguage.korean;
  AppLanguage _targetLanguage = AppLanguage.korean;
  String _defaultContext = '일상';
  bool _reduceMotion = false;
  bool _highContrast = false;
  String _expressionMode = 'standard';
  KineticGenerationMode _kineticGenerationMode = KineticGenerationMode.basic;
  SpeechCaptureMode _speechCaptureMode = SpeechCaptureMode.single;
  double _textScale = 1;
  bool _storeAudioSamples = false;
  bool _improveRecognition = false;
  String? _email;
  List<String> _dictionary = [];
  List<ConversationRecord> _conversationHistory = [];

  SessionMode get sessionMode => _sessionMode;
  bool get hasSession => _sessionMode != SessionMode.none;
  bool get isGuest => _sessionMode == SessionMode.guest;
  bool get onboardingComplete => _onboardingComplete;
  AppLanguage get sourceLanguage => _sourceLanguage;
  AppLanguage get targetLanguage => _targetLanguage;
  LanguagePair get languagePair =>
      LanguagePair(source: _sourceLanguage, target: _targetLanguage);
  String get defaultContext => _defaultContext;
  bool get reduceMotion => _reduceMotion;
  bool get highContrast => _highContrast;
  String get expressionMode => _expressionMode;
  KineticGenerationMode get kineticGenerationMode => _kineticGenerationMode;
  SpeechCaptureMode get speechCaptureMode => _speechCaptureMode;
  double get textScale => _textScale;
  bool get storeAudioSamples => _storeAudioSamples;
  bool get improveRecognition => _improveRecognition;
  String? get email => _email;
  List<String> get dictionary => List.unmodifiable(_dictionary);
  List<ConversationRecord> get conversationHistory =>
      List.unmodifiable(_conversationHistory);

  void continueAsGuest() {
    _sessionMode = SessionMode.guest;
    _email = null;
    _commit();
  }

  void signIn(String email) {
    _sessionMode = SessionMode.signedIn;
    _email = email;
    _commit();
  }

  void signOut() {
    _sessionMode = SessionMode.none;
    _email = null;
    _commit();
  }

  void completeOnboarding() {
    _onboardingComplete = true;
    _commit();
  }

  void setLanguagePair({
    required AppLanguage source,
    required AppLanguage target,
  }) {
    _sourceLanguage = source;
    _targetLanguage = AppEnvironment.crossLanguageEnabled || source == target
        ? target
        : source;
    _commit();
  }

  void setDefaultContext(String value) {
    _defaultContext = value;
    _commit();
  }

  void setReduceMotion(bool value) {
    _reduceMotion = value;
    _commit();
  }

  void setHighContrast(bool value) {
    _highContrast = value;
    _commit();
  }

  void setExpressionMode(String value) {
    _expressionMode = value;
    _commit();
  }

  void setKineticGenerationMode(KineticGenerationMode value) {
    _kineticGenerationMode = value;
    _commit();
  }

  void setSpeechCaptureMode(SpeechCaptureMode value) {
    _speechCaptureMode = value;
    _commit();
  }

  void setTextScale(double value) {
    _textScale = value.clamp(0.9, 1.6).toDouble();
    _commit();
  }

  void setStoreAudioSamples(bool value) {
    _storeAudioSamples = value;
    _commit();
  }

  void setImproveRecognition(bool value) {
    _improveRecognition = value;
    _commit();
  }

  void addDictionaryWord(String word) {
    final normalized = word.trim();
    if (normalized.isEmpty || _dictionary.contains(normalized)) return;
    _dictionary = [..._dictionary, normalized];
    _commit();
  }

  void removeDictionaryWord(String word) {
    _dictionary = _dictionary.where((item) => item != word).toList();
    _commit();
  }

  void addConversationRecord(ConversationRecord record) {
    _conversationHistory = [
      record,
      ..._conversationHistory,
    ].take(200).toList(growable: false);
    _commit();
  }

  void clearConversationHistory() {
    if (_conversationHistory.isEmpty) return;
    _conversationHistory = [];
    _commit();
  }

  void deleteConversationRecords(Iterable<String> recordIds) {
    final ids = recordIds.toSet();
    if (ids.isEmpty) return;
    final remaining = _conversationHistory
        .where((record) => !ids.contains(record.id))
        .toList(growable: false);
    if (remaining.length == _conversationHistory.length) return;
    _conversationHistory = remaining;
    _commit();
  }

  void _restore() {
    final preferences = _preferences;
    if (preferences == null) return;
    final storedSession = preferences.getInt('sessionMode') ?? 0;
    final hasCurrentSessionSchema =
        preferences.getInt('sessionSchemaVersion') != null;
    _sessionMode =
        hasCurrentSessionSchema &&
            storedSession >= 0 &&
            storedSession < SessionMode.values.length
        ? SessionMode.values[storedSession]
        : SessionMode.none;
    _onboardingComplete = preferences.getBool('onboardingComplete') ?? false;
    _sourceLanguage = AppLanguage.fromCode(
      preferences.getString('sourceLanguage'),
    );
    _targetLanguage = AppLanguage.fromCode(
      preferences.getString('targetLanguage'),
    );
    if (!AppEnvironment.crossLanguageEnabled &&
        _sourceLanguage != _targetLanguage) {
      _targetLanguage = _sourceLanguage;
    }
    _defaultContext = preferences.getString('defaultContextV2') ?? '일상';
    _reduceMotion = preferences.getBool('reduceMotion') ?? false;
    _highContrast = preferences.getBool('highContrast') ?? false;
    _expressionMode = preferences.getString('expressionMode') ?? 'standard';
    _kineticGenerationMode = KineticGenerationMode.fromName(
      preferences.getString('kineticGenerationMode'),
    );
    _speechCaptureMode = SpeechCaptureMode.fromName(
      preferences.getString('speechCaptureMode'),
    );
    _textScale = preferences.getDouble('textScale') ?? 1;
    _storeAudioSamples = preferences.getBool('storeAudioSamples') ?? false;
    _improveRecognition = preferences.getBool('improveRecognition') ?? false;
    _email = hasCurrentSessionSchema ? preferences.getString('email') : null;
    final storedDictionary =
        preferences.getStringList('dictionary') ?? const [];
    _dictionary = preferences.getInt('dictionarySchemaVersion') == null
        ? []
        : storedDictionary;
    _conversationHistory = _decodeHistory(
      preferences.getString('conversationHistoryV1'),
    );
  }

  void _commit() {
    notifyListeners();
    final preferences = _preferences;
    if (preferences == null) return;
    unawaited(preferences.setInt('sessionMode', _sessionMode.index));
    unawaited(preferences.setInt('sessionSchemaVersion', 1));
    unawaited(preferences.setBool('onboardingComplete', _onboardingComplete));
    unawaited(preferences.setString('sourceLanguage', _sourceLanguage.code));
    unawaited(preferences.setString('targetLanguage', _targetLanguage.code));
    unawaited(preferences.setString('defaultContextV2', _defaultContext));
    unawaited(preferences.setBool('reduceMotion', _reduceMotion));
    unawaited(preferences.setBool('highContrast', _highContrast));
    unawaited(preferences.setString('expressionMode', _expressionMode));
    unawaited(
      preferences.setString(
        'kineticGenerationMode',
        _kineticGenerationMode.name,
      ),
    );
    unawaited(
      preferences.setString('speechCaptureMode', _speechCaptureMode.name),
    );
    unawaited(preferences.setDouble('textScale', _textScale));
    unawaited(preferences.setBool('storeAudioSamples', _storeAudioSamples));
    unawaited(preferences.setBool('improveRecognition', _improveRecognition));
    if (_email == null) {
      unawaited(preferences.remove('email'));
    } else {
      unawaited(preferences.setString('email', _email!));
    }
    unawaited(preferences.setStringList('dictionary', _dictionary));
    unawaited(preferences.setInt('dictionarySchemaVersion', 1));
    unawaited(
      preferences.setString(
        'conversationHistoryV1',
        jsonEncode(
          _conversationHistory.map((record) => record.toJson()).toList(),
        ),
      ),
    );
  }

  List<ConversationRecord> _decodeHistory(String? value) {
    if (value == null || value.isEmpty) return [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ConversationRecord.fromJson)
          .where(
            (record) =>
                record.originalText.isNotEmpty && record.resultText.isNotEmpty,
          )
          .take(200)
          .toList(growable: false);
    } on Object {
      return [];
    }
  }
}
