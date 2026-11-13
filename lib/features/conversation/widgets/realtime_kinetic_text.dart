import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../kinetic/realtime/realtime_kinetic_tokens.dart';
import '../kinetic/realtime/realtime_kinetic_types.dart';

/// Line height for composed typography.
///
/// Words carry a vertical offset that layout cannot see, so lines need more
/// air than plain text of the same size would.
const double _composedLineHeight = 1.76;

/// How present a word still feels, by how far back in the line it sits.
///
/// Speech that has already gone by recedes rather than vanishing, so a speaker
/// can see the composition building while the newest words stay foremost.
double _recession(int index, int total) {
  const foremost = 16;
  final back = total - 1 - index;
  if (back <= foremost) return 1;
  final faded = ((back - foremost) / 26).clamp(0.0, 1.0);
  return (1 - faded * 0.58).clamp(0.42, 1.0);
}

/// Lays words out so a line break never lands inside one.
///
/// Each word is an atomic [WidgetSpan]; the spaces between them are real text.
/// Keeping the separators outside the widgets is what gives the line breaker
/// actual word boundaries to work with — with the whitespace tucked inside a
/// placeholder the paragraph is one unbroken run and words get split.
List<InlineSpan> _wordSpans(
  List<RealtimeKineticSegment> segments,
  Widget Function(RealtimeKineticSegment segment, int index) build,
) {
  final spans = <InlineSpan>[];
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    final word = segment.text.trimRight();
    if (word.isNotEmpty) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: build(segment.withText(word), index),
        ),
      );
    }
    if (word.length != segment.text.length) {
      spans.add(const TextSpan(text: ' '));
    }
  }
  return spans;
}

class RealtimeKineticText extends StatelessWidget {
  const RealtimeKineticText({required this.plan, super.key});

  final RealtimeKineticPlan plan;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final spans = <InlineSpan>[
      ..._wordSpans(
        plan.committed,
        (segment, index) => _RealtimeSegmentView(
          key: ValueKey(segment.id),
          segment: segment,
          provisional: false,
          reducedMotion: reducedMotion,
          recession: _recession(index, plan.committed.length),
        ),
      ),
      ..._wordSpans(
        plan.provisional,
        (segment, _) => _RealtimeSegmentView(
          key: ValueKey(segment.id),
          segment: segment,
          provisional: true,
          reducedMotion: reducedMotion,
        ),
      ),
    ];

    return Semantics(
      liveRegion: true,
      label: '${plan.currentLine} ${plan.provisionalLine}'.trim(),
      excludeSemantics: true,
      child: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vertical room for the pitch contour, which is painted with a
            // transform and therefore does not claim layout space itself.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text.rich(
                TextSpan(children: spans),
                textAlign: TextAlign.center,
                style: AppTypography.displayTranslation.copyWith(
                  fontSize: RealtimeKineticTokens.baseFontSize,
                  height: 1.18,
                ),
                strutStyle: const StrutStyle(
                  fontFamily: AppTypography.family,
                  fontSize: RealtimeKineticTokens.baseFontSize,
                  height: _composedLineHeight,
                  forceStrutHeight: true,
                ),
              ),
            ),
            if (plan.provisional.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DraftDot(delay: 0),
                    SizedBox(width: 4),
                    _DraftDot(delay: 80),
                    SizedBox(width: 4),
                    _DraftDot(delay: 160),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Replays a finished live session exactly as it was composed.
///
/// The live stage only ever shows two lines, so this reuses the retained
/// per-word treatment for the whole utterance. Entrance animations are skipped:
/// the speaker already watched these words arrive, and re-animating a whole
/// paragraph at once reads as noise.
class RealtimeKineticTranscript extends StatelessWidget {
  const RealtimeKineticTranscript({required this.segments, super.key});

  final List<RealtimeKineticSegment> segments;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: segments.map((segment) => segment.text).join(),
      excludeSemantics: true,
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text.rich(
            TextSpan(
              children: _wordSpans(
                segments,
                (segment, _) => _StaticSegmentView(segment: segment),
              ),
            ),
            textAlign: TextAlign.center,
            style: AppTypography.displayTranslation.copyWith(
              fontSize: RealtimeKineticTokens.baseFontSize,
              height: 1.18,
            ),
            strutStyle: const StrutStyle(
              fontFamily: AppTypography.family,
              fontSize: RealtimeKineticTokens.baseFontSize,
              height: _composedLineHeight,
              forceStrutHeight: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticSegmentView extends StatelessWidget {
  const _StaticSegmentView({required this.segment});

  final RealtimeKineticSegment segment;

  @override
  Widget build(BuildContext context) {
    final peak = segment.role == RealtimeEmphasisRole.peak;
    final style = AppTypography.displayTranslation.copyWith(
      fontSize: RealtimeKineticTokens.baseFontSize * segment.fontScale,
      height: 1.18,
      fontWeight: RealtimeKineticTokens.weightFor(segment),
      fontVariations: [
        FontVariation('wght', segment.weightAxis.clamp(300, 900)),
      ],
      color: RealtimeKineticTokens.colorFor(segment, provisional: false),
      letterSpacing: segment.letterSpacing,
    );
    return Opacity(
      opacity: segment.restingOpacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(segment.horizontalBias, segment.verticalBias),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: peak
                ? Border(
                    bottom: BorderSide(
                      color: AppColors.accent.withValues(
                        alpha: 0.24 * segment.emphasis,
                      ),
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: Text.rich(TextSpan(text: segment.text, style: style)),
        ),
      ),
    );
  }
}

class _RealtimeSegmentView extends StatefulWidget {
  const _RealtimeSegmentView({
    required this.segment,
    required this.provisional,
    required this.reducedMotion,
    this.recession = 1,
    super.key,
  });

  final RealtimeKineticSegment segment;
  final bool provisional;
  final bool reducedMotion;

  /// 1 for the newest words, lower for speech that has already gone by.
  final double recession;

  @override
  State<_RealtimeSegmentView> createState() => _RealtimeSegmentViewState();
}

class _RealtimeSegmentViewState extends State<_RealtimeSegmentView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.segment.durationMs),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reducedMotion ||
        widget.segment.motion == RealtimeKineticMotion.neutral) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _RealtimeSegmentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = Duration(milliseconds: widget.segment.durationMs);
    if (widget.reducedMotion) {
      _controller.value = 1;
      return;
    }
    final committedNow = oldWidget.provisional && !widget.provisional;
    final visualChanged =
        oldWidget.segment.visualSignature != widget.segment.visualSignature;
    final textChanged = oldWidget.segment.text != widget.segment.text;
    if (committedNow || visualChanged || textChanged) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final segment = widget.segment;
    final token = RealtimeKineticTokens.motions[segment.motion]!;
    // Draft words keep their measured size; only colour and opacity mark them
    // as still being revised.
    final scale = segment.fontScale;
    final peak = segment.role == RealtimeEmphasisRole.peak;
    final textStyle = AppTypography.displayTranslation.copyWith(
      fontSize: RealtimeKineticTokens.baseFontSize * scale,
      height: 1.18,
      fontWeight: RealtimeKineticTokens.weightFor(segment),
      // Pretendard is registered as a variable face, so weight can move
      // continuously with measured loudness instead of in nine steps.
      fontVariations: [
        FontVariation('wght', segment.weightAxis.clamp(300, 900)),
      ],
      color: RealtimeKineticTokens.colorFor(
        segment,
        provisional: widget.provisional,
      ),
      letterSpacing: segment.letterSpacing,
      shadows: peak && segment.emphasis > 0.86
          ? const [
              Shadow(
                color: AppColors.accentSoft,
                blurRadius: 14,
                offset: Offset(0, 3),
              ),
            ]
          : null,
    );
    final child = DecoratedBox(
      decoration: BoxDecoration(
        border: peak
            ? Border(
                bottom: BorderSide(
                  color: AppColors.accent.withValues(
                    alpha: 0.24 * segment.emphasis,
                  ),
                  width: 2,
                ),
              )
            : null,
      ),
      child: Text.rich(TextSpan(text: segment.text, style: textStyle)),
    );

    final restingOpacity =
        (widget.provisional
                ? RealtimeKineticTokens.provisionalOpacity
                : segment.restingOpacity) *
            widget.recession;

    if (widget.reducedMotion) {
      return Opacity(
        opacity: restingOpacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(segment.horizontalBias, segment.verticalBias),
          child: child,
        ),
      );
    }
    final curved = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.22, 1, 0.36, 1),
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final frame = _frame(curved.value, token, segment.motion);
        return Opacity(
          opacity: (frame.opacity * restingOpacity).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              frame.dx + segment.horizontalBias,
              frame.dy + segment.verticalBias,
            ),
            child: Transform.scale(scale: frame.scale, child: child),
          ),
        );
      },
    );
  }

  _RealtimeFrame _frame(
    double t,
    RealtimeMotionToken token,
    RealtimeKineticMotion motion,
  ) {
    final opacity = _lerp(token.opacityFrom, 1, t);
    final dx = _lerp(token.offsetX, 0, t);
    final dy = switch (motion) {
      RealtimeKineticMotion.lift => _twoStage(t, token.offsetY, -3, 0),
      RealtimeKineticMotion.drop ||
      RealtimeKineticMotion.settle => _twoStage(t, token.offsetY, 3, 0),
      _ => _lerp(token.offsetY, 0, t),
    };
    final scale = switch (motion) {
      RealtimeKineticMotion.pulse ||
      RealtimeKineticMotion.snap ||
      RealtimeKineticMotion.stretch => _twoStage(
        t,
        token.scaleFrom,
        token.peakScale,
        1,
      ),
      _ => _lerp(token.scaleFrom, 1, t),
    };
    return _RealtimeFrame(opacity: opacity, dx: dx, dy: dy, scale: scale);
  }

  double _twoStage(double t, double start, double peak, double end) {
    const split = 0.62;
    return t < split
        ? _lerp(start, peak, t / split)
        : _lerp(peak, end, (t - split) / (1 - split));
  }

  double _lerp(double start, double end, double t) => start + (end - start) * t;
}

class _RealtimeFrame {
  const _RealtimeFrame({
    required this.opacity,
    required this.dx,
    required this.dy,
    required this.scale,
  });

  final double opacity;
  final double dx;
  final double dy;
  final double scale;
}

class _DraftDot extends StatelessWidget {
  const _DraftDot({required this.delay});

  final int delay;

  @override
  Widget build(BuildContext context) {
    // Kept static under reduced motion; the staggered opacity itself is enough
    // to communicate a mutable tail without a perpetual animation controller.
    final opacity = MediaQuery.disableAnimationsOf(context)
        ? 0.36
        : 0.30 + (delay / 160) * 0.18;
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}
