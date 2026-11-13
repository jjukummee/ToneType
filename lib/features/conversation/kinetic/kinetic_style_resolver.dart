import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/kinetic_segment.dart';
import 'kinetic_design_tokens.dart';

class KineticVisualStyle {
  const KineticVisualStyle({
    required this.fontScale,
    required this.fontWeight,
    required this.opacity,
    required this.verticalOffset,
    required this.letterSpacing,
    required this.duration,
    required this.curve,
    required this.peakScale,
  });

  final double fontScale;
  final FontWeight fontWeight;
  final double opacity;
  final double verticalOffset;
  final double letterSpacing;
  final Duration duration;
  final Curve curve;
  final double peakScale;
}

abstract final class KineticStyleResolver {
  static KineticVisualStyle resolve({
    required KineticMotion motion,
    required KineticIntensity intensity,
    KineticExpressionMode mode = KineticExpressionMode.standard,
    bool reducedMotion = false,
    Duration? scheduledDuration,
  }) {
    final token = KineticMotionTokens.values[motion]!;
    final strength = KineticMotionTokens.intensity[intensity]!;
    final modeFactor = KineticMotionTokens.expression[mode]!;
    final movement = reducedMotion ? 0.0 : strength * modeFactor;
    final scale = 1.0 + token.scaleDelta * strength;
    final peakScale = 1.0 + math.min(0.18, token.peakDelta * movement);
    final offset = token.verticalOffset * movement;
    final spacing = token.letterSpacing * strength;
    final opacity = math.max(0.72, 1 - token.opacityLoss * strength);
    final duration = scheduledDuration ?? token.duration;

    return KineticVisualStyle(
      fontScale: scale.clamp(0.9, 1.20),
      fontWeight: token.fontWeight,
      opacity: opacity.clamp(0.72, 1),
      verticalOffset: offset.clamp(-8, 8),
      letterSpacing: spacing,
      duration: reducedMotion ? Duration.zero : duration,
      curve: const Cubic(0.22, 1, 0.36, 1),
      peakScale: reducedMotion ? scale : peakScale.clamp(0.9, 1.20),
    );
  }
}
