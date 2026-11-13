import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'realtime_kinetic_types.dart';

class RealtimeMotionToken {
  const RealtimeMotionToken({
    required this.durationMs,
    this.scaleFrom = 0.98,
    this.peakScale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.opacityFrom = 0.72,
  });

  final int durationMs;
  final double scaleFrom;
  final double peakScale;
  final double offsetX;
  final double offsetY;
  final double opacityFrom;
}

abstract final class RealtimeKineticTokens {
  static const baseFontSize = 27.0;
  static const provisionalOpacity = 0.62;
  static const provisionalScale = 0.985;

  static const motions = <RealtimeKineticMotion, RealtimeMotionToken>{
    RealtimeKineticMotion.neutral: RealtimeMotionToken(durationMs: 120),
    RealtimeKineticMotion.pulse: RealtimeMotionToken(
      durationMs: 210,
      scaleFrom: 0.90,
      peakScale: 1.16,
      offsetY: 3,
      opacityFrom: 0.72,
    ),
    RealtimeKineticMotion.lift: RealtimeMotionToken(
      durationMs: 185,
      scaleFrom: 0.95,
      peakScale: 1.07,
      offsetY: 7,
    ),
    RealtimeKineticMotion.drop: RealtimeMotionToken(
      durationMs: 215,
      scaleFrom: 1.05,
      offsetY: -6,
    ),
    RealtimeKineticMotion.snap: RealtimeMotionToken(
      durationMs: 140,
      scaleFrom: 0.93,
      peakScale: 1.06,
      offsetY: 3,
      opacityFrom: 0.78,
    ),
    RealtimeKineticMotion.glide: RealtimeMotionToken(
      durationMs: 150,
      offsetX: 6,
      opacityFrom: 0.46,
    ),
    RealtimeKineticMotion.breathe: RealtimeMotionToken(
      durationMs: 275,
      scaleFrom: 0.965,
      offsetX: 2,
      opacityFrom: 0.52,
    ),
    RealtimeKineticMotion.rush: RealtimeMotionToken(
      durationMs: 120,
      scaleFrom: 0.94,
      offsetX: 9,
      opacityFrom: 0.72,
    ),
    RealtimeKineticMotion.trail: RealtimeMotionToken(
      durationMs: 240,
      offsetX: -5,
      opacityFrom: 0.50,
    ),
    RealtimeKineticMotion.hold: RealtimeMotionToken(
      durationMs: 285,
      scaleFrom: 0.985,
      opacityFrom: 0.70,
    ),
    RealtimeKineticMotion.stretch: RealtimeMotionToken(
      durationMs: 260,
      scaleFrom: 0.90,
      peakScale: 1.08,
      opacityFrom: 0.66,
    ),
    RealtimeKineticMotion.settle: RealtimeMotionToken(
      durationMs: 220,
      scaleFrom: 1.045,
      offsetY: -5,
      opacityFrom: 0.74,
    ),
  };

  /// A single three-stop ink ramp: hush, ink, accent.
  ///
  /// Keeping every word on one ramp is what lets size and colour vary freely
  /// without the composition fragmenting — there is only ever one hue in play.
  static Color colorFor(
    RealtimeKineticSegment segment, {
    required bool provisional,
  }) {
    if (provisional) return _draft(_rampColor(segment));
    return _rampColor(segment);
  }

  static Color _rampColor(RealtimeKineticSegment segment) {
    final value = segment.emphasis.clamp(0.0, 1.0);
    if (value < 0.34) {
      return Color.lerp(AppColors.inkFaint, AppColors.inkSoft, value / 0.34)!;
    }
    if (value < 0.68) {
      return Color.lerp(
        AppColors.inkSoft,
        AppColors.ink,
        (value - 0.34) / 0.34,
      )!;
    }
    // Crossing into the accent band is itself the signal, so the band opens at
    // a already-visible blend rather than fading in from pure ink.
    final accent = Color.lerp(
      AppColors.ink,
      AppColors.accent,
      (0.30 + 0.70 * ((value - 0.68) / 0.32)).clamp(0.0, 1.0),
    )!;
    // Rising delivery lifts the accent a shade; falling keeps it grounded.
    return segment.toneTilt > 0.15
        ? Color.lerp(accent, AppColors.accentTop, 0.35)!
        : accent;
  }

  /// Draft words keep their place on the ramp but are washed toward the hush,
  /// so they read as unsettled without losing the shape they were given.
  static Color _draft(Color settled) =>
      Color.lerp(settled, AppColors.inkFaint, 0.5)!;

  static FontWeight weightFor(RealtimeKineticSegment segment) {
    final step = (segment.weightAxis / 100).round().clamp(1, 9);
    return FontWeight.values[step - 1];
  }
}
