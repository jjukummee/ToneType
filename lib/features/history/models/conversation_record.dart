import '../../../core/models/app_language.dart';
import '../../../core/text/text_encoding_repair.dart';
import '../../conversation/kinetic/realtime/realtime_kinetic_types.dart';
import '../../conversation/models/conversation_state.dart';

class ConversationRecord {
  const ConversationRecord({
    required this.id,
    required this.createdAt,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.context,
    required this.originalText,
    required this.resultText,
    this.durationSeconds,
    this.tone,
    this.kineticComposition = const [],
  });

  factory ConversationRecord.create({
    required LanguagePair languagePair,
    required String context,
    required String originalText,
    required String resultText,
    double? durationSeconds,
    ConversationToneSummary? tone,
    DateTime? createdAt,
    List<RealtimeKineticSegment> kineticComposition = const [],
  }) {
    final timestamp = createdAt ?? DateTime.now();
    return ConversationRecord(
      id: timestamp.microsecondsSinceEpoch.toString(),
      createdAt: timestamp,
      sourceLanguage: languagePair.source,
      targetLanguage: languagePair.target,
      context: context.trim().isEmpty ? '일상' : context.trim(),
      originalText: originalText.trim(),
      resultText: resultText.trim(),
      durationSeconds: durationSeconds,
      tone: tone,
      kineticComposition: kineticComposition,
    );
  }

  factory ConversationRecord.fromJson(Map<String, dynamic> json) {
    final toneJson = json['tone'];
    return ConversationRecord(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      sourceLanguage: AppLanguage.fromCode(json['source_language'] as String?),
      targetLanguage: AppLanguage.fromCode(json['target_language'] as String?),
      context: json['context'] as String? ?? '일상',
      originalText: TextEncodingRepair.restoreUtf8ByteMarkers(
        json['original_text'] as String? ?? '',
      ),
      resultText: TextEncodingRepair.restoreUtf8ByteMarkers(
        json['result_text'] as String? ?? '',
      ),
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      tone: toneJson is Map<String, dynamic>
          ? ConversationToneSummary.fromJson(toneJson)
          : null,
      kineticComposition: _decodeComposition(json['kinetic_composition']),
    );
  }

  static List<RealtimeKineticSegment> _decodeComposition(Object? value) {
    if (value is! List) return const [];
    final output = <RealtimeKineticSegment>[];
    for (var index = 0; index < value.length; index++) {
      final segment = RealtimeKineticSegment.fromJson(value[index], index);
      if (segment != null) output.add(segment);
    }
    return output;
  }

  final String id;
  final DateTime createdAt;
  final AppLanguage sourceLanguage;
  final AppLanguage targetLanguage;
  final String context;
  final String originalText;
  final String resultText;
  final double? durationSeconds;
  final ConversationToneSummary? tone;

  /// The live typography this conversation was composed with, if any.
  final List<RealtimeKineticSegment> kineticComposition;

  LanguagePair get languagePair =>
      LanguagePair(source: sourceLanguage, target: targetLanguage);

  Map<String, Object?> toJson() => {
    'id': id,
    'created_at': createdAt.toUtc().toIso8601String(),
    'source_language': sourceLanguage.code,
    'target_language': targetLanguage.code,
    'context': context,
    'original_text': originalText,
    'result_text': resultText,
    'duration_seconds': durationSeconds,
    'tone': tone?.toJson(),
    if (kineticComposition.isNotEmpty)
      'kinetic_composition': [
        for (final segment in kineticComposition) segment.toJson(),
      ],
  };
}
