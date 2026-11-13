enum KineticMotion {
  neutral,
  impact,
  soft,
  whisper,
  rise,
  settle,
  stagger,
  rapid,
  stretch,
}

enum KineticIntensity { subtle, medium, strong }

enum KineticExpressionMode { minimal, standard, immersive }

enum KineticGenerationMode {
  basic,
  hybrid;

  String get apiValue => name;
  String get label => this == basic ? '기본' : 'AI';
  String get title => this == basic ? '기본 키네틱' : 'AI 하이브리드';
  String get description => this == basic
      ? '음성 특징과 한국어 구조를 규칙으로 분석해요.'
      : 'Google AI가 문맥과 의미를 더해 연출해요.';

  static KineticGenerationMode fromName(String? value) =>
      value == hybrid.name ? hybrid : basic;
}

enum KineticResultSource { basic, hybrid, basicFallback }

enum KineticPattern {
  neutral,
  strongEmphasis,
  surprise,
  urgent,
  hesitant,
  calm,
  whisper,
  excited,
  firm,
  drawnOut,
  repetition,
  question,
}

enum KineticLayout {
  inline,
  focusCenter,
  focusEnd,
  verticalBuild,
  staggered,
  stacked,
  wideStretch,
  quietSpace,
}

class KineticTiming {
  const KineticTiming({
    this.startDelayMs = 0,
    this.durationMs = 260,
    this.holdDurationMs = 80,
    this.exitDurationMs = 0,
    this.sequenceIndex = 0,
  });

  final int startDelayMs;
  final int durationMs;
  final int holdDurationMs;
  final int exitDurationMs;
  final int sequenceIndex;

  factory KineticTiming.fromJson(Map<String, dynamic> json) => KineticTiming(
    startDelayMs: _int(json['start_delay_ms'], 0),
    durationMs: _int(json['duration_ms'], 260),
    holdDurationMs: _int(json['hold_duration_ms'], 80),
    exitDurationMs: _int(json['exit_duration_ms'], 0),
    sequenceIndex: _int(json['sequence_index'], 0),
  );
}

class KineticDebugInfo {
  const KineticDebugInfo({
    required this.acousticScore,
    required this.linguisticScore,
    required this.finalSalience,
    this.matchedRules = const [],
  });

  final double acousticScore;
  final double linguisticScore;
  final double finalSalience;
  final List<String> matchedRules;
}

class KineticSegment {
  const KineticSegment({
    required this.text,
    this.motion = KineticMotion.neutral,
    this.intensity = KineticIntensity.subtle,
    this.salience = 0,
    this.timing = const KineticTiming(),
    this.debug,
  });

  final String text;
  final KineticMotion motion;
  final KineticIntensity intensity;
  final double salience;
  final KineticTiming timing;
  final KineticDebugInfo? debug;

  factory KineticSegment.fromJson(Map<String, dynamic> json) {
    return KineticSegment(
      text: json['text'] as String? ?? '',
      motion: _enumByName(
        KineticMotion.values,
        json['motion'],
        KineticMotion.neutral,
      ),
      intensity: _enumByName(
        KineticIntensity.values,
        json['intensity'],
        KineticIntensity.subtle,
      ),
      salience: _score(json['salience']),
      timing: KineticTiming.fromJson(json),
    );
  }

  KineticSegment copyWith({
    String? text,
    KineticMotion? motion,
    KineticIntensity? intensity,
    double? salience,
    KineticTiming? timing,
    KineticDebugInfo? debug,
  }) {
    return KineticSegment(
      text: text ?? this.text,
      motion: motion ?? this.motion,
      intensity: intensity ?? this.intensity,
      salience: salience ?? this.salience,
      timing: timing ?? this.timing,
      debug: debug ?? this.debug,
    );
  }
}

class KineticPlan {
  const KineticPlan({
    required this.mode,
    required this.pattern,
    required this.layout,
    required this.segments,
    this.version = 2,
    this.interpretation,
  });

  factory KineticPlan.neutral(
    String text, {
    KineticGenerationMode mode = KineticGenerationMode.basic,
  }) => KineticPlan(
    mode: mode,
    pattern: KineticPattern.neutral,
    layout: KineticLayout.inline,
    segments: text.isEmpty ? const [] : [KineticSegment(text: text)],
  );

  factory KineticPlan.hybridFromJson({
    required String transcript,
    required Map<String, dynamic> json,
  }) {
    final rawSegments = json['segments'];
    final segments = rawSegments is List
        ? rawSegments
              .whereType<Map<String, dynamic>>()
              .map(KineticSegment.fromJson)
              .where((segment) => segment.text.isNotEmpty)
              .toList(growable: false)
        : const <KineticSegment>[];
    if (segments.map((segment) => segment.text).join() != transcript) {
      return KineticPlan.neutral(
        transcript,
        mode: KineticGenerationMode.hybrid,
      );
    }
    return KineticPlan(
      mode: KineticGenerationMode.hybrid,
      pattern: _enumByName(
        KineticPattern.values,
        json['pattern'],
        KineticPattern.neutral,
      ),
      layout: _enumByName(
        KineticLayout.values,
        json['layout'],
        KineticLayout.inline,
      ),
      interpretation: (json['interpretation'] as String?)?.trim(),
      segments: [
        for (var index = 0; index < segments.length; index++)
          segments[index].copyWith(
            timing: KineticTiming(
              startDelayMs: segments[index].timing.startDelayMs == 0
                  ? index * 80
                  : segments[index].timing.startDelayMs,
              durationMs: segments[index].timing.durationMs,
              holdDurationMs: segments[index].timing.holdDurationMs,
              exitDurationMs: segments[index].timing.exitDurationMs,
              sequenceIndex: index,
            ),
          ),
      ],
    );
  }

  final int version;
  final KineticGenerationMode mode;
  final KineticPattern pattern;
  final KineticLayout layout;
  final List<KineticSegment> segments;
  final String? interpretation;

  String get transcript => segments.map((segment) => segment.text).join();
}

T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  final name = value?.toString();
  return values.firstWhere(
    (candidate) => candidate.name == name,
    orElse: () => fallback,
  );
}

int _int(Object? value, int fallback) =>
    value is num ? value.round() : fallback;
double _score(Object? value) =>
    value is num ? value.toDouble().clamp(0.0, 1.0) : 0;
