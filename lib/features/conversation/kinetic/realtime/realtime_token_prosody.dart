import 'dart:math' as math;

import 'realtime_kinetic_types.dart';

/// One short slice of analysed microphone audio on the audio sample clock.
class ProsodyFrame {
  const ProsodyFrame({
    required this.timeMs,
    required this.rms,
    required this.pitch,
  });

  final double timeMs;
  final double rms;

  /// Normalised 0..1 pitch, or `double.nan` when the frame is unvoiced.
  final double pitch;

  bool get voiced => !pitch.isNaN;
}

/// Attaches measured audio to individual recognised words.
///
/// Google's streaming recogniser only reports word offsets on final results,
/// and it delivers text in bursts that lag the speech that produced it. Rather
/// than guessing that latency, this aligner attributes the audio observed
/// *since the previous commit* to the words that arrived in this commit, split
/// by syllable weight. The offset is systematic, so words stay comparable to
/// each other — which is all a speaker-relative visual mapping needs.
///
/// Once a word is assigned it is never recomputed, so settled typography stops
/// moving while later words are still being recognised.
class RealtimeTokenProsodyAligner {
  final List<String> _tokens = [];
  final List<TokenProsody> _prosody = [];

  /// Where each token's audio window began, so a discarded tail can be
  /// measured again from the same speech instead of from silence.
  final List<double> _windowStart = [];

  double _markerMs = 0;

  // Speaker-relative baselines, updated only from observed speech.
  double _loudCenter = 0;
  double _loudSpread = 0;
  double _pitchCenter = 0.5;
  double _pitchSpread = 0;
  double _syllableMs = 0;
  int _observed = 0;

  List<TokenProsody> get tokens => List.unmodifiable(_prosody);

  void reset() {
    _tokens.clear();
    _prosody.clear();
    _windowStart.clear();
    _markerMs = 0;
    _loudCenter = 0;
    _loudSpread = 0;
    _pitchCenter = 0.5;
    _pitchSpread = 0;
    _syllableMs = 0;
    _observed = 0;
  }

  /// Reconciles [text] with what has already been measured and returns the
  /// per-token prosody for it.
  ///
  /// [text] is the transcript as currently displayed, which includes interim
  /// words. Measuring those too is what lets typography appear while someone
  /// is still speaking; a recogniser rewrite simply discards the affected tail
  /// and re-measures it.
  List<TokenProsody> sync({
    required String text,
    required List<ProsodyFrame> frames,
    required double audioMs,
  }) {
    final incoming = RegExp(r'\S+')
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList(growable: false);

    // Keep the longest matching prefix. A recogniser rewrite past that point
    // discards only the affected tail instead of the whole line.
    var shared = 0;
    while (shared < _tokens.length &&
        shared < incoming.length &&
        _tokens[shared] == incoming[shared]) {
      shared++;
    }
    if (shared < _tokens.length) {
      // Rewind to where the discarded words began. Leaving the marker ahead
      // would hand their replacements an empty window, and every re-measured
      // word would fall back to neutral — the composition goes flat exactly
      // when the recogniser is revising most.
      _markerMs = math.min(_markerMs, _windowStart[shared]);
      _tokens.removeRange(shared, _tokens.length);
      _prosody.removeRange(shared, _prosody.length);
      _windowStart.removeRange(shared, _windowStart.length);
    }
    if (incoming.length == _tokens.length) {
      _markerMs = math.max(_markerMs, audioMs);
      return List.unmodifiable(_prosody);
    }

    final arriving = incoming.sublist(_tokens.length);
    final windowStart = _markerMs;
    final window = frames
        .where((frame) => frame.timeMs >= windowStart)
        .toList(growable: false);
    final measured = _measure(arriving, window);
    for (var index = 0; index < arriving.length; index++) {
      _tokens.add(arriving[index]);
      _prosody.add(measured[index]);
      _windowStart.add(windowStart);
    }
    _markerMs = math.max(_markerMs, audioMs);
    return List.unmodifiable(_prosody);
  }

  List<TokenProsody> _measure(List<String> arriving, List<ProsodyFrame> window) {
    final weights = [for (final token in arriving) _syllables(token).toDouble()];
    final total = weights.fold<double>(0, (sum, value) => sum + value);
    final voiced = window.where((frame) => frame.rms > 0).toList(growable: false);
    if (voiced.isEmpty || total <= 0) {
      return [for (final _ in arriving) const TokenProsody()];
    }

    final spanMs = voiced.last.timeMs - voiced.first.timeMs;
    final output = <TokenProsody>[];
    var consumed = 0.0;
    for (var index = 0; index < arriving.length; index++) {
      final from = voiced.first.timeMs + spanMs * (consumed / total);
      consumed += weights[index];
      final to = voiced.first.timeMs + spanMs * (consumed / total);
      final slice = voiced
          .where((frame) => frame.timeMs >= from && frame.timeMs <= to)
          .toList(growable: false);
      output.add(
        _fromSlice(
          slice.isEmpty ? voiced : slice,
          syllables: math.max(1, weights[index].round()),
          durationMs: math.max(1.0, to - from),
          pauseAfter: index == arriving.length - 1
              ? _trailingSilence(window)
              : 0,
        ),
      );
    }
    return output;
  }

  TokenProsody _fromSlice(
    List<ProsodyFrame> slice, {
    required int syllables,
    required double durationMs,
    required double pauseAfter,
  }) {
    var loudSum = 0.0;
    var loudPeak = 0.0;
    final pitches = <double>[];
    for (final frame in slice) {
      loudSum += frame.rms;
      loudPeak = math.max(loudPeak, frame.rms);
      if (frame.voiced) pitches.add(frame.pitch);
    }
    // Peak-weighted: a word is "loud" because of its loudest moment, not
    // because it happened to contain few quiet gaps.
    final rawLoudness = loudPeak * 0.6 + (loudSum / slice.length) * 0.4;
    final rawPitch = pitches.isEmpty ? double.nan : _median(pitches);
    final syllableMs = durationMs / syllables;

    _observe(
      loudness: rawLoudness,
      pitch: rawPitch,
      syllableMs: syllableMs,
    );

    final loudness = _relative(rawLoudness, _loudCenter, _loudSpread);
    final pitch = rawPitch.isNaN
        ? 0.5
        : _relative(rawPitch, _pitchCenter, _pitchSpread);
    final slope = pitches.length < 3 ? 0.0 : _slope(pitches);
    final stretch = _syllableMs <= 0
        ? 0.5
        : (0.5 + (syllableMs / _syllableMs - 1) * 0.85).clamp(0.0, 1.0);

    return TokenProsody(
      loudness: loudness,
      pitch: pitch,
      pitchSlope: slope.clamp(-1.0, 1.0),
      stretch: stretch,
      energy: (loudness * 0.68 + (pitches.isEmpty ? 0.3 : 0.5) * 0.32).clamp(
        0.0,
        1.0,
      ),
      pauseAfter: pauseAfter,
      voiced: pitches.isNotEmpty,
    );
  }

  void _observe({
    required double loudness,
    required double pitch,
    required double syllableMs,
  }) {
    final alpha = _observed < 4 ? 0.5 : 0.12;
    if (_observed == 0) {
      _loudCenter = loudness;
      _loudSpread = loudness * 0.35;
      _syllableMs = syllableMs;
      if (!pitch.isNaN) {
        _pitchCenter = pitch;
        _pitchSpread = 0.08;
      }
    } else {
      _loudSpread = _ema(_loudSpread, (loudness - _loudCenter).abs(), alpha);
      _loudCenter = _ema(_loudCenter, loudness, alpha);
      _syllableMs = _ema(_syllableMs, syllableMs, alpha);
      if (!pitch.isNaN) {
        _pitchSpread = _ema(_pitchSpread, (pitch - _pitchCenter).abs(), alpha);
        _pitchCenter = _ema(_pitchCenter, pitch, alpha);
      }
    }
    _observed++;
  }

  /// Maps a raw value onto 0..1 around the speaker's own centre.
  ///
  /// A guard keeps microphone noise from being amplified into extreme scores:
  /// until a real contrast has been observed everything reads as neutral.
  double _relative(double value, double center, double spread) {
    if (value.isNaN) return 0.5;
    final range = math.max(spread * 2, 1e-4);
    if (spread < 1e-3) return 0.5;
    return (0.5 + (value - center) / (range * 2)).clamp(0.0, 1.0);
  }

  double _slope(List<double> values) {
    final n = values.length;
    var sumX = 0.0;
    var sumY = 0.0;
    var sumXy = 0.0;
    var sumXx = 0.0;
    for (var index = 0; index < n; index++) {
      sumX += index;
      sumY += values[index];
      sumXy += index * values[index];
      sumXx += index * index.toDouble();
    }
    final denominator = n * sumXx - sumX * sumX;
    if (denominator.abs() < 1e-9) return 0;
    return ((n * sumXy - sumX * sumY) / denominator) * n * 2;
  }

  double _trailingSilence(List<ProsodyFrame> window) {
    var silent = 0;
    for (var index = window.length - 1; index >= 0; index--) {
      if (window[index].rms > 0) break;
      silent++;
    }
    return silent * 0.02;
  }

  int _syllables(String token) {
    final hangul = token.runes
        .where((code) => code >= 0xAC00 && code <= 0xD7A3)
        .length;
    if (hangul > 0) return hangul;
    final bare = token.replaceAll(RegExp(r'[\s,.!?…~～。！？]'), '');
    return math.max(1, bare.runes.length);
  }

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _ema(double current, double next, double alpha) =>
      current + (next - current) * alpha;
}
