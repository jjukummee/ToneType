import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../kinetic/kinetic_style_resolver.dart';
import '../models/kinetic_segment.dart';

class KineticText extends StatelessWidget {
  const KineticText({
    required this.plan,
    super.key,
    this.mode = KineticExpressionMode.standard,
    this.textAlign = TextAlign.center,
    this.emphasizedWord,
  });

  final KineticPlan plan;
  final KineticExpressionMode mode;
  final TextAlign textAlign;
  final String? emphasizedWord;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final children = [
      for (var index = 0; index < plan.segments.length; index++)
        _KineticSegmentView(
          key: ValueKey(
            '${plan.segments[index].text}-${plan.segments[index].timing.sequenceIndex}',
          ),
          segment: plan.segments[index],
          mode: mode,
          reducedMotion: reducedMotion,
          emphasizedWord: emphasizedWord,
        ),
    ];
    return Semantics(
      label: plan.transcript,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: _KineticLayoutView(
          plan: plan,
          textAlign: textAlign,
          children: children,
        ),
      ),
    );
  }
}

class _KineticLayoutView extends StatelessWidget {
  const _KineticLayoutView({
    required this.plan,
    required this.children,
    required this.textAlign,
  });

  final KineticPlan plan;
  final List<Widget> children;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => switch (plan.layout) {
    KineticLayout.inline => _inline(),
    KineticLayout.focusCenter => _focus(dominantAtEnd: false),
    KineticLayout.focusEnd => _focus(dominantAtEnd: true),
    KineticLayout.verticalBuild => _column(spacing: 8),
    KineticLayout.stacked => _column(spacing: 3),
    KineticLayout.quietSpace => _column(spacing: 15),
    KineticLayout.staggered => Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 10,
      children: [
        for (var index = 0; index < children.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index.isOdd ? 8 : 0),
            child: children[index],
          ),
      ],
    ),
    KineticLayout.wideStretch => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: _inline(),
    ),
  };

  Widget _inline() {
    return Text.rich(
      TextSpan(
        children: [
          for (final child in children)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: child,
            ),
        ],
      ),
      textAlign: textAlign,
    );
  }

  Widget _focus({required bool dominantAtEnd}) {
    if (children.length <= 1) return _inline();
    var dominant = 0;
    for (var index = 1; index < plan.segments.length; index++) {
      if (plan.segments[index].salience > plan.segments[dominant].salience) {
        dominant = index;
      }
    }
    if (dominantAtEnd && dominant < children.length - 2) {
      dominant = children.length - 1;
    }
    final before = children.take(dominant).toList();
    final after = children.skip(dominant + 1).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (before.isNotEmpty)
          Wrap(alignment: WrapAlignment.center, children: before),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: children[dominant],
        ),
        if (after.isNotEmpty)
          Wrap(alignment: WrapAlignment.center, children: after),
      ],
    );
  }

  Widget _column({required double spacing}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

class _KineticSegmentView extends StatefulWidget {
  const _KineticSegmentView({
    required this.segment,
    required this.mode,
    required this.reducedMotion,
    required this.emphasizedWord,
    super.key,
  });

  final KineticSegment segment;
  final KineticExpressionMode mode;
  final bool reducedMotion;
  final String? emphasizedWord;

  @override
  State<_KineticSegmentView> createState() => _KineticSegmentViewState();
}

class _KineticSegmentViewState extends State<_KineticSegmentView>
    with SingleTickerProviderStateMixin {
  late final KineticVisualStyle _style = KineticStyleResolver.resolve(
    motion: widget.segment.motion,
    intensity: widget.segment.intensity,
    mode: widget.mode,
    reducedMotion: widget.reducedMotion,
    scheduledDuration: Duration(milliseconds: widget.segment.timing.durationMs),
  );
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _style.duration,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_style.duration == Duration.zero ||
        widget.segment.motion == KineticMotion.neutral) {
      _controller.value = 1;
    } else {
      _timer = Timer(
        Duration(milliseconds: 140 + widget.segment.timing.startDelayMs),
        _controller.forward,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: _style.curve);

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        final frame = _frameFor(t);
        return Opacity(
          opacity: (_style.opacity * frame.opacity).clamp(0, 1),
          child: Transform.translate(
            offset: Offset(frame.dx, frame.dy),
            child: Transform.scale(
              scaleX: frame.scaleX,
              scaleY: frame.scaleY,
              child: child,
            ),
          ),
        );
      },
      child: _textChild(),
    );
  }

  Widget _textChild() {
    final word = widget.emphasizedWord?.trim();
    final match = word == null || word.isEmpty
        ? -1
        : widget.segment.text.indexOf(word);
    final baseStyle = AppTypography.displayTranslation.copyWith(
      color: match >= 0 ? AppColors.ink : _colorFor(widget.segment.motion),
      fontWeight: _style.fontWeight,
      fontSize: AppTypography.displayTranslation.fontSize! * _style.fontScale,
      letterSpacing: _style.letterSpacing,
      shadows:
          widget.segment.motion == KineticMotion.impact &&
              widget.segment.intensity == KineticIntensity.strong
          ? const [
              Shadow(
                color: AppColors.accentSoft,
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ]
          : null,
    );
    if (match < 0 || word == null) {
      return Text(
        widget.segment.text,
        textAlign: TextAlign.center,
        style: baseStyle,
      );
    }
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          if (match > 0)
            TextSpan(text: widget.segment.text.substring(0, match)),
          TextSpan(
            text: word,
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (match + word.length < widget.segment.text.length)
            TextSpan(text: widget.segment.text.substring(match + word.length)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  _KineticFrame _frameFor(double t) {
    final distance = _style.verticalOffset.abs().clamp(0.0, 8.0);
    return switch (widget.segment.motion) {
      KineticMotion.neutral => const _KineticFrame(),
      KineticMotion.impact => _KineticFrame(
        opacity: (t * 3.2).clamp(0.0, 1.0),
        dy: _lerp(distance, 0, t),
        scaleX: _twoStage(t, 0.82, _style.peakScale, 1),
        scaleY: _twoStage(t, 0.82, _style.peakScale, 1),
      ),
      KineticMotion.soft => _KineticFrame(
        opacity: t,
        dy: _lerp(distance, 0, t),
        scaleX: _lerp(0.96, 1, t),
        scaleY: _lerp(0.96, 1, t),
      ),
      KineticMotion.whisper => _KineticFrame(
        opacity: t,
        dx: _lerp(-4, 0, t),
        dy: _lerp(distance * 0.6, 0, t),
        scaleX: _lerp(0.93, 1, t),
        scaleY: _lerp(0.97, 1, t),
      ),
      KineticMotion.rise => _KineticFrame(
        opacity: (t * 2.2).clamp(0.0, 1.0),
        dy: _twoStage(t, distance, -2, 0, split: 0.76),
        scaleX: _lerp(0.92, 1, t),
        scaleY: _lerp(0.92, 1, t),
      ),
      KineticMotion.settle => _KineticFrame(
        opacity: (t * 1.8).clamp(0.0, 1.0),
        dy: _lerp(-distance, 0, t),
        scaleX: _lerp(1.04, 1, t),
        scaleY: _lerp(1.04, 1, t),
      ),
      KineticMotion.stagger => _KineticFrame(
        opacity: (t * 1.7).clamp(0.0, 1.0),
        dx: _lerp(widget.segment.timing.sequenceIndex.isEven ? -7 : 7, 0, t),
        dy: _lerp(distance, 0, t),
      ),
      KineticMotion.rapid => _KineticFrame(
        opacity: (t * 3.5).clamp(0.0, 1.0),
        dx: _lerp(widget.segment.timing.sequenceIndex.isEven ? -8 : 8, 0, t),
        scaleX: _lerp(0.86, 1, t),
        scaleY: _lerp(0.94, 1, t),
      ),
      KineticMotion.stretch => _KineticFrame(
        opacity: (t * 1.8).clamp(0.0, 1.0),
        scaleX: _twoStage(t, 0.78, 1.08, 1, split: 0.72),
        scaleY: _lerp(0.96, 1, t),
      ),
    };
  }

  Color _colorFor(KineticMotion motion) => switch (motion) {
    KineticMotion.impact => AppColors.accent,
    KineticMotion.rise => AppColors.accentTop,
    KineticMotion.soft || KineticMotion.whisper => AppColors.inkSoft,
    _ => AppColors.ink,
  };

  double _twoStage(
    double t,
    double begin,
    double peak,
    double end, {
    double split = 0.58,
  }) => t < split
      ? _lerp(begin, peak, t / split)
      : _lerp(peak, end, (t - split) / (1 - split));

  double _lerp(double begin, double end, double t) => begin + (end - begin) * t;
}

class _KineticFrame {
  const _KineticFrame({
    this.opacity = 1,
    this.dx = 0,
    this.dy = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  final double opacity;
  final double dx;
  final double dy;
  final double scaleX;
  final double scaleY;
}
