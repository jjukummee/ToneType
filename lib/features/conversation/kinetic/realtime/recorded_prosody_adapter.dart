import 'dart:math' as math;

import '../../models/prosody_result.dart';
import 'realtime_kinetic_planner.dart';
import 'realtime_kinetic_types.dart';

/// Feeds a completed recording to the live composition engine.
///
/// Stop-then-analyze capture measures the same things the live tracker does,
/// only after the fact and on the server: per-word loudness, pitch, duration
/// and the pause that followed. Restating them as [TokenProsody] lets both
/// capture modes share one composition engine, so a sentence looks the same
/// however it was captured.
abstract final class RecordedProsodyAdapter {
  static List<RealtimeKineticSegment> compose({
    required String displayText,
    required ProsodyAnalysisResult prosody,
  }) {
    if (displayText.trim().isEmpty) return const [];
    final planner = RealtimeKineticPlanner();
    planner.plan(
      preview: displayText,
      committed: displayText,
      stability: 1,
      prosody: snapshot(displayText: displayText, prosody: prosody),
    );
    return planner.composition;
  }

  static RealtimeProsodySnapshot snapshot({
    required String displayText,
    required ProsodyAnalysisResult prosody,
  }) {
    final utterance = prosody.utterance;
    return RealtimeProsodySnapshot(
      relativeLoudness: (utterance.volume - 0.5) * 2,
      pitchDeviation: ((utterance.pitch ?? 0.5) - 0.5) * 2,
      pitchSlope: switch (utterance.intonation) {
        ProsodyIntonation.rising => 0.4,
        ProsodyIntonation.falling => -0.4,
        _ => 0.0,
      },
      energy: utterance.energy,
      speedDeviation: ((utterance.speed ?? 0.5) - 0.5) * 2,
      pause: utterance.pause,
      tokens: _tokens(displayText: displayText, prosody: prosody),
    );
  }

  static List<TokenProsody> _tokens({
    required String displayText,
    required ProsodyAnalysisResult prosody,
  }) {
    final words = RegExp(r'\S+').allMatches(displayText).length;
    final segments = prosody.segments;
    if (words == 0 || segments.isEmpty) return const [];

    // Speaking tempo, so a drawn-out word can be told from a long one.
    final perSyllable = [
      for (final segment in segments)
        segment.duration / math.max(1, _syllables(segment.text)),
    ];
    final median = _median(perSyllable);

    return [
      for (var index = 0; index < words; index++)
        _fromSegment(
          // The displayed text has been spelling-corrected, which can split or
          // join a word, so positions are mapped proportionally rather than
          // assumed to line up one for one.
          segments[(index * segments.length ~/ words).clamp(
            0,
            segments.length - 1,
          )],
          perSyllable: perSyllable[(index * segments.length ~/ words).clamp(
            0,
            segments.length - 1,
          )],
          median: median,
          utterance: prosody.utterance,
        ),
    ];
  }

  static TokenProsody _fromSegment(
    ProsodySegmentResult segment, {
    required double perSyllable,
    required double median,
    required ProsodyUtterance utterance,
  }) {
    final loudness = (segment.relativeLoudness * 0.7 + segment.emphasis * 0.3)
        .clamp(0.0, 1.0);
    return TokenProsody(
      loudness: loudness,
      pitch: segment.relativePitch ?? 0.5,
      pitchSlope: 0,
      stretch: median <= 0
          ? 0.5
          : (0.5 + (perSyllable / median - 1) * 0.85).clamp(0.0, 1.0),
      energy: (loudness * 0.68 + utterance.energy * 0.32).clamp(0.0, 1.0),
      pauseAfter: segment.pauseAfter,
      voiced: segment.relativePitch != null,
    );
  }

  static int _syllables(String text) {
    final hangul = text.runes
        .where((code) => code >= 0xAC00 && code <= 0xD7A3)
        .length;
    if (hangul > 0) return hangul;
    final bare = text.replaceAll(RegExp(r'[\s,.!?…~～。！？]'), '');
    return math.max(1, bare.runes.length);
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
