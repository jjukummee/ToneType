enum ProsodyIntonation {
  rising,
  flat,
  falling,
  unknown;

  static ProsodyIntonation fromJson(String? value) => switch (value) {
    'rising' => rising,
    'falling' => falling,
    'flat' => flat,
    _ => unknown,
  };
}

class ProsodyUtterance {
  const ProsodyUtterance({
    required this.volume,
    required this.energy,
    required this.pause,
    required this.intonation,
    this.pitch,
    this.speed,
  });

  final double volume;
  final double? pitch;
  final double? speed;
  final double energy;
  final double pause;
  final ProsodyIntonation intonation;

  factory ProsodyUtterance.fromJson(Map<String, dynamic> json) {
    return ProsodyUtterance(
      volume: _score(json['volume']),
      pitch: _nullableScore(json['pitch']),
      speed: _nullableScore(json['speed']),
      energy: _score(json['energy']),
      pause: _score(json['pause']),
      intonation: ProsodyIntonation.fromJson(json['intonation'] as String?),
    );
  }
}

class ProsodySegmentResult {
  const ProsodySegmentResult({
    required this.text,
    required this.start,
    required this.end,
    required this.duration,
    required this.relativeLoudness,
    required this.pauseAfter,
    required this.emphasis,
    this.relativePitch,
  });

  final String text;
  final double start;
  final double end;
  final double duration;
  final double relativeLoudness;
  final double? relativePitch;
  final double pauseAfter;
  final double emphasis;

  factory ProsodySegmentResult.fromJson(Map<String, dynamic> json) {
    return ProsodySegmentResult(
      text: json['text'] as String? ?? '',
      start: _number(json['start']),
      end: _number(json['end']),
      duration: _number(json['duration']),
      relativeLoudness: _score(json['relative_loudness']),
      relativePitch: _nullableScore(json['relative_pitch']),
      pauseAfter: _number(json['pause_after']),
      emphasis: _score(json['emphasis']),
    );
  }
}

class ProsodyAnalysisResult {
  const ProsodyAnalysisResult({
    required this.utterance,
    required this.segments,
  });

  final ProsodyUtterance utterance;
  final List<ProsodySegmentResult> segments;

  factory ProsodyAnalysisResult.fromJson(Map<String, dynamic> json) {
    final utteranceJson = json['utterance'];
    if (utteranceJson is! Map<String, dynamic>) {
      throw const FormatException('Missing prosody utterance.');
    }
    final segmentJson = json['segments'];
    return ProsodyAnalysisResult(
      utterance: ProsodyUtterance.fromJson(utteranceJson),
      segments: segmentJson is List
          ? segmentJson
                .whereType<Map<String, dynamic>>()
                .map(ProsodySegmentResult.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class ProsodyWordTimestamp {
  const ProsodyWordTimestamp({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;
  final double start;
  final double end;

  Map<String, Object> toJson() => {'text': text, 'start': start, 'end': end};
}

double _number(Object? value) => value is num ? value.toDouble() : 0;

double _score(Object? value) => _number(value).clamp(0.0, 1.0);

double? _nullableScore(Object? value) =>
    value is num ? value.toDouble().clamp(0.0, 1.0) : null;
