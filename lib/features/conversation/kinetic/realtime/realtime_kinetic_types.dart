enum RealtimeWordLifecycle {
  incoming,
  provisional,
  committed,
  emphasized,
  settled,
  archived,
}

enum RealtimeKineticMotion {
  neutral,
  pulse,
  lift,
  drop,
  snap,
  glide,
  breathe,
  rush,
  trail,
  hold,
  stretch,
  settle,
}

enum RealtimeKineticIntensity { subtle, medium, strong }

/// The visual role a token plays inside one live line.
///
/// Exactly one [peak] is allowed per line. This is what keeps a dynamic
/// composition from turning into noise: contrast comes from a single loud
/// voice against a calm field, not from every word shouting.
enum RealtimeEmphasisRole { calm, secondary, peak }

/// One token's own measured acoustics, expressed speaker-relative.
///
/// Unlike [RealtimeProsodySnapshot] — which describes the current instant of
/// the microphone — this describes the slice of audio that produced a specific
/// word. It is frozen once the word is committed so that settled typography
/// stops twitching while later words are still arriving.
class TokenProsody {
  const TokenProsody({
    this.loudness = 0.5,
    this.pitch = 0.5,
    this.pitchSlope = 0,
    this.stretch = 0.5,
    this.energy = 0.5,
    this.pauseAfter = 0,
    this.voiced = true,
  });

  /// 0..1 within the speaker's own recent range.
  final double loudness;

  /// 0..1 relative to the speaker's rolling median pitch.
  final double pitch;

  /// -1..1 pitch movement measured inside this token.
  final double pitchSlope;

  /// 0..1 syllable duration versus the speaker's own tempo. 0.5 is normal.
  final double stretch;

  /// 0..1 blended loudness and pitch activity.
  final double energy;

  /// Seconds of silence measured after this token.
  final double pauseAfter;

  final bool voiced;

  /// Signed distance from the speaker's median pitch, -1..1.
  double get pitchDelta => (pitch - 0.5) * 2;
}

class RealtimeProsodySnapshot {
  const RealtimeProsodySnapshot({
    this.relativeLoudness = 0,
    this.pitchDeviation = 0,
    this.pitchSlope = 0,
    this.energy = 0.5,
    this.speedDeviation = 0,
    this.pause = 0,
    this.durationAnomaly = 0,
    this.tokens = const [],
  });

  final double relativeLoudness;
  final double pitchDeviation;
  final double pitchSlope;
  final double energy;
  final double speedDeviation;
  final double pause;
  final double durationAnomaly;

  /// Per-token measurements for the committed transcript, in spoken order.
  ///
  /// Empty when no audio has been observed yet; the planner then falls back to
  /// the instantaneous fields above so text-only callers keep working.
  final List<TokenProsody> tokens;
}

class RealtimeKineticSegment {
  const RealtimeKineticSegment({
    required this.id,
    required this.text,
    required this.lifecycle,
    required this.motion,
    required this.intensity,
    required this.salience,
    required this.verticalBias,
    required this.durationMs,
    required this.sequenceIndex,
    this.role = RealtimeEmphasisRole.calm,
    this.fontScale = 1,
    this.weightAxis = 500,
    this.letterSpacing = 0,
    this.horizontalBias = 0,
    this.emphasis = 0,
    this.toneTilt = 0,
    this.restingOpacity = 1,
  });

  final String id;
  final String text;
  final RealtimeWordLifecycle lifecycle;
  final RealtimeKineticMotion motion;
  final RealtimeKineticIntensity intensity;
  final double salience;

  /// Pitch contour offset in logical pixels. Negative is up.
  final double verticalBias;

  final int durationMs;
  final int sequenceIndex;

  final RealtimeEmphasisRole role;

  /// Continuous type size multiplier driven by measured loudness.
  final double fontScale;

  /// Continuous variable-font weight axis value, 300..900.
  final double weightAxis;

  /// Tracking driven by syllable tempo. Slow speech opens up, fast tightens.
  final double letterSpacing;

  final double horizontalBias;

  /// Continuous 0..1 position on the line's ink ramp.
  ///
  /// Derived from the same prominence that produced [fontScale] and
  /// [weightAxis], but rescaled against this line's own accent cut-off so that
  /// only a minority of words ever reach the accent colour.
  final double emphasis;

  /// -1..1 falling versus rising pitch, used for a restrained colour shift.
  final double toneTilt;

  /// Resting opacity used to push calm words back and pull the peak forward.
  final double restingOpacity;

  /// Compact form for on-device history.
  ///
  /// Only the channels a static replay reads are kept, rounded, and stored
  /// positionally — a spoken paragraph can run to hundreds of words and this
  /// lives in shared preferences alongside every other saved conversation.
  List<Object?> toJson() => [
    text,
    double.parse(fontScale.toStringAsFixed(3)),
    weightAxis.round(),
    double.parse(verticalBias.toStringAsFixed(2)),
    double.parse(letterSpacing.toStringAsFixed(2)),
    double.parse(emphasis.toStringAsFixed(3)),
    role.index,
    double.parse(restingOpacity.toStringAsFixed(2)),
    double.parse(toneTilt.toStringAsFixed(2)),
  ];

  static RealtimeKineticSegment? fromJson(Object? value, int index) {
    if (value is! List || value.length < 9) return null;
    final text = value[0];
    if (text is! String || text.isEmpty) return null;
    double number(Object? raw, double fallback) =>
        raw is num ? raw.toDouble() : fallback;
    final roleIndex = value[6];
    return RealtimeKineticSegment(
      id: 'saved-$index',
      text: text,
      lifecycle: RealtimeWordLifecycle.settled,
      motion: RealtimeKineticMotion.neutral,
      intensity: RealtimeKineticIntensity.subtle,
      salience: 0,
      verticalBias: number(value[3], 0),
      durationMs: 0,
      sequenceIndex: index,
      role: roleIndex is int && roleIndex >= 0 &&
              roleIndex < RealtimeEmphasisRole.values.length
          ? RealtimeEmphasisRole.values[roleIndex]
          : RealtimeEmphasisRole.calm,
      fontScale: number(value[1], 1),
      weightAxis: number(value[2], 500),
      letterSpacing: number(value[4], 0),
      emphasis: number(value[5], 0),
      restingOpacity: number(value[7], 1),
      toneTilt: number(value[8], 0),
    );
  }

  RealtimeKineticSegment withText(String value) => RealtimeKineticSegment(
    id: id,
    text: value,
    lifecycle: lifecycle,
    motion: motion,
    intensity: intensity,
    salience: salience,
    verticalBias: verticalBias,
    durationMs: durationMs,
    sequenceIndex: sequenceIndex,
    role: role,
    fontScale: fontScale,
    weightAxis: weightAxis,
    letterSpacing: letterSpacing,
    horizontalBias: horizontalBias,
    emphasis: emphasis,
    toneTilt: toneTilt,
    restingOpacity: restingOpacity,
  );

  /// Coarsely quantised so that ordinary measurement jitter does not restart
  /// the entrance animation on every frame.
  String get visualSignature =>
      '$lifecycle:$motion:$intensity:$role'
      ':${(fontScale * 20).round()}'
      ':${(weightAxis / 50).round()}'
      ':${(verticalBias / 3).round()}'
      ':${(letterSpacing * 4).round()}'
      ':${(emphasis * 6).round()}';
}

class RealtimeKineticPlan {
  const RealtimeKineticPlan({
    required this.archivedText,
    required this.committed,
    required this.provisional,
    required this.dominantWord,
    required this.revision,
  });

  const RealtimeKineticPlan.empty()
    : archivedText = '',
      committed = const [],
      provisional = const [],
      dominantWord = null,
      revision = 0;

  final String archivedText;
  final List<RealtimeKineticSegment> committed;
  final List<RealtimeKineticSegment> provisional;
  final String? dominantWord;
  final int revision;

  String get currentLine => committed.map((segment) => segment.text).join();
  String get provisionalLine =>
      provisional.map((segment) => segment.text).join();
  bool get isEmpty =>
      archivedText.isEmpty &&
      committed.isEmpty &&
      provisional.isEmpty;
}
