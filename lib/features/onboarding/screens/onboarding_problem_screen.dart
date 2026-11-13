import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tonetype_primary_button.dart';
import '../../../core/widgets/tone_top_bar.dart';
import 'onboarding_solution_screen.dart';

class OnboardingProblemScreen extends StatelessWidget {
  const OnboardingProblemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ToneStage(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ProgressDots(active: 0),
            const Spacer(flex: 2),
            const Text('번역은 됐지만,\n느낌까지 전달됐을까요?', style: AppTypography.title),
            const SizedBox(height: 42),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AccentRule(),
                SizedBox(width: 12),
                Expanded(child: _ToneComparison()),
              ],
            ),
            const Spacer(flex: 3),
            const Text(
              '같은 말도, 말투에 따라 전혀 다르게 들리니까요.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            ToneTypePrimaryButton(
              label: '계속',
              onPressed: () =>
                  pushScreen(context, const OnboardingSolutionScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToneComparison extends StatelessWidget {
  const _ToneComparison();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('“Are you serious?”', style: AppTypography.body),
        SizedBox(height: 28),
        Text('• 놀란 말투', style: AppTypography.caption),
        SizedBox(height: 4),
        Text(
          '헐, 진짜?',
          style: TextStyle(
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w400,
            color: AppColors.inkSoft,
          ),
        ),
        SizedBox(height: 24),
        Text('• 단호한 말투', style: AppTypography.caption),
        SizedBox(height: 4),
        Text(
          '너 지금 진심이야?',
          style: TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }
}

class _AccentRule extends StatelessWidget {
  const _AccentRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 150,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent, Color(0x102F6BFF)],
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: index == active ? 14 : 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: index == active
                    ? AppColors.accent
                    : AppColors.ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
