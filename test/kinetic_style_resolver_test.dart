import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/core/theme/app_colors.dart';
import 'package:tonetype/features/conversation/kinetic/kinetic_style_resolver.dart';
import 'package:tonetype/features/conversation/models/kinetic_segment.dart';
import 'package:tonetype/features/conversation/widgets/kinetic_text.dart';

void main() {
  test('kinetic style remains inside animation safety limits', () {
    for (final motion in KineticMotion.values) {
      for (final intensity in KineticIntensity.values) {
        final style = KineticStyleResolver.resolve(
          motion: motion,
          intensity: intensity,
          mode: KineticExpressionMode.immersive,
        );

        expect(style.fontScale, inInclusiveRange(0.9, 1.20));
        expect(style.peakScale, inInclusiveRange(0.9, 1.20));
        expect(style.verticalOffset, inInclusiveRange(-8, 8));
        expect(style.opacity, inInclusiveRange(0.65, 1));
      }
    }
  });

  test('reduced motion removes positional animation', () {
    final style = KineticStyleResolver.resolve(
      motion: KineticMotion.impact,
      intensity: KineticIntensity.strong,
      reducedMotion: true,
    );

    expect(style.verticalOffset, 0);
    expect(style.duration, Duration.zero);
  });

  testWidgets('translation renderer highlights the measured emphasized word', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KineticText(
            plan: KineticPlan(
              mode: KineticGenerationMode.basic,
              pattern: KineticPattern.neutral,
              layout: KineticLayout.inline,
              segments: [KineticSegment(text: '내일 말고 오늘 해 줘.')],
            ),
            emphasizedWord: '오늘',
          ),
        ),
      ),
    );

    final richText = tester.widgetList<RichText>(find.byType(RichText));
    expect(
      richText.any((widget) => _containsAccentWord(widget.text, '오늘')),
      isTrue,
    );
  });
}

bool _containsAccentWord(InlineSpan span, String word) {
  if (span case TextSpan(:final text, :final style, :final children)) {
    if (text == word && style?.color == AppColors.accent) return true;
    return children?.any((child) => _containsAccentWord(child, word)) ?? false;
  }
  return false;
}
