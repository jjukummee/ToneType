import '../kinetic/realtime/realtime_kinetic_types.dart';
import 'kinetic_segment.dart';
import 'prosody_result.dart';
import 'speech_capture_mode.dart';

enum ToneAnalysisMode {
  wordFocused,
  sentenceFocused;

  static ToneAnalysisMode fromJson(String? value) => values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ToneAnalysisMode.wordFocused,
  );
}

class ToneWordInsight {
  const ToneWordInsight({
    required this.text,
    required this.start,
    required this.end,
    required this.loudness,
    required this.pauseAfter,
    required this.emphasis,
    this.pitch,
  });

  final String text;
  final double start;
  final double end;
  final double loudness;
  final double? pitch;
  final double pauseAfter;
  final double emphasis;

  double get duration => (end - start).clamp(0, double.infinity);

  factory ToneWordInsight.fromJson(Map<String, dynamic> json) {
    return ToneWordInsight(
      text: json['text'] as String? ?? '',
      start: _number(json['start']),
      end: _number(json['end']),
      loudness: _score(json['loudness']),
      pitch: _nullableScore(json['pitch']),
      pauseAfter: _number(json['pause_after']),
      emphasis: _score(json['emphasis']),
    );
  }

  Map<String, Object?> toJson() => {
    'text': text,
    'start': start,
    'end': end,
    'loudness': loudness,
    'pitch': pitch,
    'pause_after': pauseAfter,
    'emphasis': emphasis,
  };
}

class ToneSentenceInsight {
  const ToneSentenceInsight({
    required this.text,
    required this.start,
    required this.end,
    required this.volume,
    required this.energy,
    required this.pauseAfter,
    required this.intonation,
    required this.coreSummary,
    this.pitch,
    this.speed,
    this.peakWord,
  });

  final String text;
  final double start;
  final double end;
  final double volume;
  final double? pitch;
  final double? speed;
  final double energy;
  final double pauseAfter;
  final ProsodyIntonation intonation;
  final String? peakWord;
  final String coreSummary;

  factory ToneSentenceInsight.fromJson(Map<String, dynamic> json) {
    return ToneSentenceInsight(
      text: json['text'] as String? ?? '',
      start: _number(json['start']),
      end: _number(json['end']),
      volume: _score(json['volume']),
      pitch: _nullableScore(json['pitch']),
      speed: _nullableScore(json['speed']),
      energy: _score(json['energy']),
      pauseAfter: _number(json['pause_after']),
      intonation: ProsodyIntonation.fromJson(json['intonation'] as String?),
      peakWord: (json['peak_word'] as String?)?.trim(),
      coreSummary: json['core_summary'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'text': text,
    'start': start,
    'end': end,
    'volume': volume,
    'pitch': pitch,
    'speed': speed,
    'energy': energy,
    'pause_after': pauseAfter,
    'intonation': intonation.name,
    'peak_word': peakWord,
    'core_summary': coreSummary,
  };
}

class ConversationToneSummary {
  const ConversationToneSummary({
    required this.volume,
    required this.energy,
    required this.pause,
    required this.intonation,
    this.pitch,
    this.speed,
    this.emphasizedWord,
    this.analysisMode = ToneAnalysisMode.wordFocused,
    this.deliverySummary = '',
    this.wordInsights = const [],
    this.sentenceInsights = const [],
    this.durationSeconds = 0,
  });

  final double volume;
  final double? pitch;
  final double? speed;
  final double energy;
  final double pause;
  final ProsodyIntonation intonation;
  final String? emphasizedWord;
  final ToneAnalysisMode analysisMode;
  final String deliverySummary;
  final List<ToneWordInsight> wordInsights;
  final List<ToneSentenceInsight> sentenceInsights;
  final double durationSeconds;

  ConversationToneSummary copyWith({String? emphasizedWord}) {
    return ConversationToneSummary(
      volume: volume,
      pitch: pitch,
      speed: speed,
      energy: energy,
      pause: pause,
      intonation: intonation,
      emphasizedWord: emphasizedWord ?? this.emphasizedWord,
      analysisMode: analysisMode,
      deliverySummary: deliverySummary,
      wordInsights: wordInsights,
      sentenceInsights: sentenceInsights,
      durationSeconds: durationSeconds,
    );
  }

  factory ConversationToneSummary.fromProsody(
    ProsodyAnalysisResult prosody, {
    String transcript = '',
    SpeechCaptureMode captureMode = SpeechCaptureMode.single,
  }) {
    final words = prosody.segments
        .where((segment) => segment.text.trim().isNotEmpty)
        .map(
          (segment) => ToneWordInsight(
            text: segment.text.trim(),
            start: segment.start,
            end: segment.end,
            loudness: segment.relativeLoudness,
            pitch: segment.relativePitch,
            pauseAfter: segment.pauseAfter,
            emphasis: segment.emphasis,
          ),
        )
        .toList(growable: false);
    final emphasized = prosody.segments.isEmpty
        ? null
        : prosody.segments.reduce(
            (current, next) =>
                next.emphasis > current.emphasis ? next : current,
          );
    final emphasizedWord = emphasized != null && emphasized.emphasis >= 0.4
        ? emphasized.text.trim()
        : null;
    final sentences = _buildSentenceInsights(
      transcript: transcript,
      words: words,
      utterance: prosody.utterance,
    );
    return ConversationToneSummary(
      volume: prosody.utterance.volume,
      pitch: prosody.utterance.pitch,
      speed: prosody.utterance.speed,
      energy: prosody.utterance.energy,
      pause: prosody.utterance.pause,
      intonation: prosody.utterance.intonation,
      emphasizedWord: emphasizedWord,
      analysisMode: captureMode == SpeechCaptureMode.live
          ? ToneAnalysisMode.sentenceFocused
          : ToneAnalysisMode.wordFocused,
      deliverySummary: _deliverySummary(
        volume: prosody.utterance.volume,
        speed: prosody.utterance.speed,
        pause: prosody.utterance.pause,
        intonation: prosody.utterance.intonation,
        emphasizedWord: emphasizedWord,
      ),
      wordInsights: words,
      sentenceInsights: sentences,
      durationSeconds: words.isEmpty ? 0 : words.last.end,
    );
  }

  factory ConversationToneSummary.fromJson(Map<String, dynamic> json) {
    return ConversationToneSummary(
      volume: _score(json['volume']),
      pitch: _nullableScore(json['pitch']),
      speed: _nullableScore(json['speed']),
      energy: _score(json['energy']),
      pause: _score(json['pause']),
      intonation: ProsodyIntonation.fromJson(json['intonation'] as String?),
      emphasizedWord: (json['emphasized_word'] as String?)?.trim(),
      analysisMode: ToneAnalysisMode.fromJson(json['analysis_mode'] as String?),
      deliverySummary: json['delivery_summary'] as String? ?? '',
      wordInsights: _mapJsonList(
        json['word_insights'],
        ToneWordInsight.fromJson,
      ),
      sentenceInsights: _mapJsonList(
        json['sentence_insights'],
        ToneSentenceInsight.fromJson,
      ),
      durationSeconds: _number(json['duration_seconds']),
    );
  }

  Map<String, Object?> toJson() => {
    'volume': volume,
    'pitch': pitch,
    'speed': speed,
    'energy': energy,
    'pause': pause,
    'intonation': intonation.name,
    'emphasized_word': emphasizedWord,
    'analysis_mode': analysisMode.name,
    'delivery_summary': deliverySummary,
    'word_insights': wordInsights.map((word) => word.toJson()).toList(),
    'sentence_insights': sentenceInsights
        .map((sentence) => sentence.toJson())
        .toList(),
    'duration_seconds': durationSeconds,
  };
}

List<ToneSentenceInsight> _buildSentenceInsights({
  required String transcript,
  required List<ToneWordInsight> words,
  required ProsodyUtterance utterance,
}) {
  final sentenceTexts = RegExp(r'[^.!?…。！？]+(?:[.!?…。！？]+|$)')
      .allMatches(transcript.trim())
      .map((match) => match.group(0)!.trim())
      .where((text) => text.isNotEmpty)
      .toList();
  if (sentenceTexts.isEmpty) {
    if (transcript.trim().isEmpty && words.isEmpty) return const [];
    sentenceTexts.add(
      transcript.trim().isNotEmpty
          ? transcript.trim()
          : words.map((word) => word.text).join(' '),
    );
  }

  final groups = <List<ToneWordInsight>>[];
  var cursor = 0;
  for (var index = 0; index < sentenceTexts.length; index++) {
    final remaining = words.length - cursor;
    final expected = sentenceTexts[index]
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .length;
    final take = index == sentenceTexts.length - 1
        ? remaining
        : expected.clamp(0, remaining);
    groups.add(words.skip(cursor).take(take).toList(growable: false));
    cursor += take;
  }

  return List.generate(sentenceTexts.length, (index) {
    final group = groups[index];
    if (group.isEmpty) {
      return ToneSentenceInsight(
        text: sentenceTexts[index],
        start: 0,
        end: 0,
        volume: utterance.volume,
        pitch: utterance.pitch,
        speed: utterance.speed,
        energy: utterance.energy,
        pauseAfter: 0,
        intonation: utterance.intonation,
        coreSummary: '문장 단위 음향 정보가 충분하지 않아 전체 말투 기준으로 표시했어요.',
      );
    }
    final peak = group.reduce(
      (current, next) => next.emphasis > current.emphasis ? next : current,
    );
    final volume = _average(group.map((word) => word.loudness));
    final pitchValues = group
        .map((word) => word.pitch)
        .whereType<double>()
        .toList(growable: false);
    final pitch = pitchValues.isEmpty ? null : _average(pitchValues);
    final duration = (group.last.end - group.first.start).clamp(0.01, 9999);
    final speed = ((group.length / duration - 0.8) / 3.2).clamp(0.0, 1.0);
    final energy = _average(
      group.map((word) => word.emphasis * 0.55 + word.loudness * 0.45),
    );
    final intonation = _sentenceIntonation(group, utterance.intonation);
    final pauseAfter = group.last.pauseAfter;
    return ToneSentenceInsight(
      text: sentenceTexts[index],
      start: group.first.start,
      end: group.last.end,
      volume: volume,
      pitch: pitch,
      speed: speed,
      energy: energy,
      pauseAfter: pauseAfter,
      intonation: intonation,
      peakWord: peak.emphasis >= 0.4 ? peak.text : null,
      coreSummary: _sentenceCoreSummary(
        peak: peak,
        intonation: intonation,
        pauseAfter: pauseAfter,
      ),
    );
  }, growable: false);
}

ProsodyIntonation _sentenceIntonation(
  List<ToneWordInsight> words,
  ProsodyIntonation fallback,
) {
  final pitches = words
      .map((word) => word.pitch)
      .whereType<double>()
      .toList(growable: false);
  if (pitches.length < 2) return fallback;
  final delta = pitches.last - pitches.first;
  if (delta >= 0.12) return ProsodyIntonation.rising;
  if (delta <= -0.12) return ProsodyIntonation.falling;
  return ProsodyIntonation.flat;
}

String _sentenceCoreSummary({
  required ToneWordInsight peak,
  required ProsodyIntonation intonation,
  required double pauseAfter,
}) {
  final parts = <String>[];
  if (peak.emphasis >= 0.65) {
    parts.add('“${peak.text}”에 가장 큰 힘을 실었어요');
  } else {
    parts.add('강조가 한곳에 치우치지 않고 고르게 이어졌어요');
  }
  parts.add(switch (intonation) {
    ProsodyIntonation.rising => '끝으로 갈수록 음높이가 올라갔어요',
    ProsodyIntonation.falling => '끝에서 음높이를 내려 문장을 닫았어요',
    ProsodyIntonation.flat => '음높이 변화가 크지 않아 차분하게 이어졌어요',
    ProsodyIntonation.unknown => '억양 방향은 뚜렷하지 않았어요',
  });
  if (pauseAfter >= 0.35) {
    parts.add('뒤에 ${pauseAfter.toStringAsFixed(1)}초 쉼을 두었어요');
  }
  return '${parts.join(' · ')}.';
}

String _deliverySummary({
  required double volume,
  required double? speed,
  required double pause,
  required ProsodyIntonation intonation,
  required String? emphasizedWord,
}) {
  final volumeText = volume >= 0.67
      ? '큰 음량'
      : volume >= 0.34
      ? '보통 음량'
      : '작은 음량';
  final speedText = speed == null
      ? '측정 가능한 속도 정보 없이'
      : speed >= 0.67
      ? '빠른 속도로'
      : speed >= 0.34
      ? '보통 속도로'
      : '천천히';
  final pauseText = pause >= 0.5
      ? '쉼을 자주 두며'
      : pause >= 0.22
      ? '적당한 쉼을 두며'
      : '쉼을 짧게 가져가며';
  final ending = switch (intonation) {
    ProsodyIntonation.rising => '끝을 올리는 흐름',
    ProsodyIntonation.falling => '끝을 내리는 흐름',
    ProsodyIntonation.flat => '높낮이가 고른 흐름',
    ProsodyIntonation.unknown => '뚜렷한 억양 방향이 없는 흐름',
  };
  final emphasis = emphasizedWord == null
      ? ''
      : ' “${emphasizedWord.trim()}”에서 강조가 가장 선명했습니다.';
  return '$volumeText과 $speedText, $pauseText $ending으로 전달했어요.$emphasis';
}

double _average(Iterable<double> values) {
  var count = 0;
  var total = 0.0;
  for (final value in values) {
    total += value;
    count++;
  }
  return count == 0 ? 0 : total / count;
}

List<T> _mapJsonList<T>(
  Object? value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);
}

enum ConversationUiState {
  idle,
  requestingPermission,
  listening,
  processing,
  finalTranslation,
  permissionDenied,
  error,
}

class ConversationStateModel {
  const ConversationStateModel({
    required this.state,
    this.originalText = '',
    this.finalTranslation = '',
    this.kineticPlan,
    this.statusMessage = '',
    this.tone,
    this.kineticSource = KineticResultSource.basic,
    this.kineticInterpretation,
    this.isLive = false,
    this.livePreviewText = '',
    this.liveCommittedText = '',
    this.realtimeComposition = const [],
  });

  const ConversationStateModel.idle() : this(state: ConversationUiState.idle);

  final ConversationUiState state;
  final String originalText;
  final String finalTranslation;
  final KineticPlan? kineticPlan;
  List<KineticSegment> get segments => kineticPlan?.segments ?? const [];
  final String statusMessage;
  final ConversationToneSummary? tone;
  final KineticResultSource kineticSource;
  final String? kineticInterpretation;
  final bool isLive;
  final String livePreviewText;
  final String liveCommittedText;

  /// The typography a speaker watched being built during a live session.
  ///
  /// Empty for keyboard input and for stop-then-analyze capture, which have no
  /// live stage to preserve.
  final List<RealtimeKineticSegment> realtimeComposition;

  /// Carries a finished live composition into the result state.
  ///
  /// The composition is dropped unless it reproduces the transcript exactly,
  /// so a recogniser revision can never leave stale styling attached to words
  /// it no longer belongs to.
  ConversationStateModel withRealtimeComposition(
    List<RealtimeKineticSegment> composition,
  ) {
    String flatten(String value) =>
        value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final rendered = flatten(
      composition.map((segment) => segment.text).join(),
    );
    if (composition.isEmpty || rendered != flatten(finalTranslation)) {
      return this;
    }
    return ConversationStateModel(
      state: state,
      originalText: originalText,
      finalTranslation: finalTranslation,
      kineticPlan: kineticPlan,
      statusMessage: statusMessage,
      tone: tone,
      kineticSource: kineticSource,
      kineticInterpretation: kineticInterpretation,
      isLive: isLive,
      livePreviewText: livePreviewText,
      liveCommittedText: liveCommittedText,
      realtimeComposition: composition,
    );
  }

  static const listening = ConversationStateModel(
    state: ConversationUiState.listening,
  );

  static const requestingPermission = ConversationStateModel(
    state: ConversationUiState.requestingPermission,
    statusMessage: '마이크 사용 권한을 확인하고 있어요.',
  );

  static const processing = ConversationStateModel(
    state: ConversationUiState.processing,
    statusMessage: '말투와 강조를 정리하고 있어요.',
  );

  const ConversationStateModel.permissionDenied()
    : this(
        state: ConversationUiState.permissionDenied,
        statusMessage: '설정에서 마이크 권한을 허용해주세요.',
      );

  ConversationStateModel.error(String message)
    : this(state: ConversationUiState.error, statusMessage: message);
}

double _number(Object? value) => value is num ? value.toDouble() : 0;
double _score(Object? value) => _number(value).clamp(0.0, 1.0);
double? _nullableScore(Object? value) =>
    value is num ? value.toDouble().clamp(0.0, 1.0) : null;
