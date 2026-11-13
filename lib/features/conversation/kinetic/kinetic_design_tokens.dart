import 'package:flutter/material.dart';

import '../models/kinetic_segment.dart';

class KineticMotionToken {
  const KineticMotionToken({
    this.scaleDelta = 0,
    this.peakDelta = 0,
    this.verticalOffset = 0,
    this.letterSpacing = 0,
    this.opacityLoss = 0,
    this.fontWeight = FontWeight.w600,
    this.duration = const Duration(milliseconds: 260),
  });

  final double scaleDelta;
  final double peakDelta;
  final double verticalOffset;
  final double letterSpacing;
  final double opacityLoss;
  final FontWeight fontWeight;
  final Duration duration;
}

abstract final class KineticMotionTokens {
  static const values = <KineticMotion, KineticMotionToken>{
    KineticMotion.neutral: KineticMotionToken(),
    KineticMotion.impact: KineticMotionToken(
      scaleDelta: 0.09,
      peakDelta: 0.18,
      verticalOffset: -8,
      fontWeight: FontWeight.w800,
      duration: Duration(milliseconds: 220),
    ),
    KineticMotion.soft: KineticMotionToken(
      scaleDelta: -0.04,
      verticalOffset: 4,
      opacityLoss: 0.22,
      fontWeight: FontWeight.w400,
      duration: Duration(milliseconds: 430),
    ),
    KineticMotion.whisper: KineticMotionToken(
      scaleDelta: -0.05,
      verticalOffset: 3,
      letterSpacing: 0.28,
      opacityLoss: 0.25,
      fontWeight: FontWeight.w400,
      duration: Duration(milliseconds: 470),
    ),
    KineticMotion.rise: KineticMotionToken(
      scaleDelta: 0.035,
      peakDelta: 0.14,
      verticalOffset: -8,
      fontWeight: FontWeight.w700,
      duration: Duration(milliseconds: 230),
    ),
    KineticMotion.settle: KineticMotionToken(
      verticalOffset: 4,
      letterSpacing: 0.42,
      fontWeight: FontWeight.w600,
      duration: Duration(milliseconds: 300),
    ),
    KineticMotion.stagger: KineticMotionToken(
      verticalOffset: 5,
      opacityLoss: 0.08,
      duration: Duration(milliseconds: 340),
    ),
    KineticMotion.rapid: KineticMotionToken(
      letterSpacing: -0.32,
      fontWeight: FontWeight.w700,
      duration: Duration(milliseconds: 180),
    ),
    KineticMotion.stretch: KineticMotionToken(
      scaleDelta: 0.06,
      letterSpacing: 1.05,
      fontWeight: FontWeight.w700,
      duration: Duration(milliseconds: 450),
    ),
  };

  static const intensity = <KineticIntensity, double>{
    KineticIntensity.subtle: 0.48,
    KineticIntensity.medium: 0.78,
    KineticIntensity.strong: 1,
  };

  static const expression = <KineticExpressionMode, double>{
    KineticExpressionMode.minimal: 0.18,
    KineticExpressionMode.standard: 0.90,
    KineticExpressionMode.immersive: 1,
  };
}
