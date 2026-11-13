import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';

class MicrophoneControl extends StatefulWidget {
  const MicrophoneControl({
    required this.active,
    required this.onPressed,
    super.key,
    this.amplitude = 0,
    this.enabled = true,
    this.compact = false,
    this.pitch = 0.5,
    this.pitchConfidence = 0,
    this.voiceReactive = false,
  });

  final bool active;
  final VoidCallback onPressed;
  final double amplitude;
  final bool enabled;
  final bool compact;
  final double pitch;
  final double pitchConfidence;
  final bool voiceReactive;

  @override
  State<MicrophoneControl> createState() => _MicrophoneControlState();
}

class _MicrophoneControlState extends State<MicrophoneControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _breathing.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MicrophoneControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _breathing.repeat(reverse: true);
    } else {
      _breathing.animateBack(0, duration: AppMotion.normal);
    }
  }

  @override
  void dispose() {
    _breathing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final outerSize = widget.compact ? 62.0 : 126.0;
    final buttonSize = widget.compact ? 48.0 : 82.0;
    final firstRing = widget.compact ? 53.0 : 104.0;
    final secondRing = widget.compact ? 61.0 : 120.0;
    final reactive = widget.active && widget.voiceReactive && !widget.compact;
    final amplitude = widget.amplitude.clamp(0.0, 1.0);
    final confidence = widget.pitchConfidence.clamp(0.0, 1.0);
    final audibleColor = Color.lerp(
      const Color(0xFF526AA7),
      const Color(0xFFC5833E),
      widget.pitch.clamp(0.0, 1.0),
    )!;
    final activeColor = reactive
        ? Color.lerp(AppColors.accent, audibleColor, confidence * 0.42)!
        : AppColors.accent;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.active ? '번역 멈추기' : '번역 시작하기',
      onTap: widget.enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: outerSize,
        child: AnimatedBuilder(
          animation: _breathing,
          builder: (context, child) {
            final breath = reduceMotion ? 0.0 : _breathing.value;
            final visualAmplitude = reduceMotion ? 0.0 : amplitude;
            final value = reactive
                ? (breath * 0.18 + visualAmplitude * 0.82).clamp(0.0, 1.0)
                : (breath * 0.45 + visualAmplitude * 0.55).clamp(0.0, 1.0);
            return Stack(
              alignment: Alignment.center,
              children: [
                if (widget.active) ...[
                  if (reactive)
                    Container(
                      width: 82 + value * 26,
                      height: 82 + value * 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeColor.withValues(
                          alpha: 0.025 + value * 0.055,
                        ),
                      ),
                    ),
                  _Ring(
                    size: firstRing + value * (widget.compact ? 4 : 8),
                    opacity: 0.26 - value * 0.08,
                    color: activeColor,
                  ),
                  _Ring(
                    size: secondRing + value * (widget.compact ? 2 : 5),
                    opacity: 0.11 - value * 0.03,
                    color: activeColor,
                  ),
                ],
                child!,
              ],
            );
          },
          child: GestureDetector(
            onTap: widget.enabled ? widget.onPressed : null,
            child: AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.standardCurve,
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.active
                    ? activeColor.withValues(
                        alpha: reactive ? 0.07 + amplitude * 0.055 : 0.08,
                      )
                    : Colors.white.withValues(alpha: 0.76),
                border: Border.all(
                  color: widget.active
                      ? activeColor
                      : Colors.white.withValues(alpha: 0.95),
                  width: widget.active ? 1.6 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (widget.active ? activeColor : AppColors.ink)
                        .withValues(alpha: widget.active ? 0.18 : 0.10),
                    blurRadius: 30,
                    spreadRadius: -8,
                    offset: const Offset(0, 12),
                  ),
                  const BoxShadow(
                    color: Color(0xBFFFFFFF),
                    blurRadius: 1,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: reactive
                  ? _VoiceReactiveGlyph(
                      amplitude: amplitude,
                      pitch: widget.pitch,
                      pitchConfidence: confidence,
                      color: activeColor,
                      reduceMotion: reduceMotion,
                    )
                  : Icon(
                      widget.active
                          ? CupertinoIcons.stop_fill
                          : CupertinoIcons.mic,
                      color: widget.enabled
                          ? AppColors.accent
                          : AppColors.inkFaint,
                      size: widget.compact ? 18 : (widget.active ? 23 : 28),
                      // A compact live dock keeps the stop action visible
                      // without covering the transcript.
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.size,
    required this.opacity,
    this.color = AppColors.accent,
  });

  final double size;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: opacity.clamp(0, 1))),
      ),
    );
  }
}

class _VoiceReactiveGlyph extends StatelessWidget {
  const _VoiceReactiveGlyph({
    required this.amplitude,
    required this.pitch,
    required this.pitchConfidence,
    required this.color,
    required this.reduceMotion,
  });

  final double amplitude;
  final double pitch;
  final double pitchConfidence;
  final Color color;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final energy = reduceMotion ? 0.35 : amplitude.clamp(0.0, 1.0);
    final pitchOffset = reduceMotion
        ? 0.0
        : ((0.5 - pitch) * 11 * pitchConfidence).clamp(-5.5, 5.5);
    const factors = [0.56, 0.82, 1.0, 0.76, 0.48];
    return Stack(
      key: const ValueKey('one-shot-voice-glyph'),
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          key: const ValueKey('one-shot-pitch-marker'),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, pitchOffset, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var index = 0; index < factors.length; index++) ...[
                AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 76),
                  curve: Curves.easeOutCubic,
                  width: index == 2 ? 4.2 : 3.2,
                  height: 7 + energy * 20 * factors[index],
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha: index == 2 ? 1 : 0.58 + energy * 0.30,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (index < factors.length - 1) const SizedBox(width: 3.5),
              ],
            ],
          ),
        ),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color.withValues(alpha: 0.72), width: 1),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 5),
            ],
          ),
        ),
      ],
    );
  }
}
