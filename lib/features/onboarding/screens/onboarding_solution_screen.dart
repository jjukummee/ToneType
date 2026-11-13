import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/state/app_scope.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tonetype_primary_button.dart';
import '../../navigation/screens/main_shell.dart';

class OnboardingSolutionScreen extends StatelessWidget {
  const OnboardingSolutionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ToneStage(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SolutionDots(),
            const SizedBox(height: 70),
            const Text('말투도 번역할 수 있어요.', style: AppTypography.title),
            const SizedBox(height: 12),
            const Text(
              '목소리의 크기, 속도, 강조를\n글자의 움직임으로 보여드려요.',
              style: AppTypography.body,
            ),
            const SizedBox(height: 34),
            const Expanded(child: _Examples()),
            ToneTypePrimaryButton(
              label: '계속',
              onPressed: () => _finishOnboarding(context),
            ),
          ],
        ),
      ),
    );
  }

  void _finishOnboarding(BuildContext context) {
    AppScope.of(context, listen: false).completeOnboarding();
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (_) => false,
    );
  }
}

class _Examples extends StatelessWidget {
  const _Examples();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Example(
          label: 'LOUD',
          hint: '크고 강하게',
          child: Text(
            '잠깐!',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
        ),
        _Example(
          label: 'QUIET',
          hint: '작고 부드럽게',
          child: Text(
            '괜찮아…',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w300,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        _Example(
          label: 'EMPHASIS',
          hint: '한 단어에 힘을 실어',
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 23, color: AppColors.ink),
              children: [
                TextSpan(text: '나는 '),
                TextSpan(
                  text: '오늘',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: '이라고 했어.'),
              ],
            ),
          ),
        ),
        _Example(
          label: 'HESITATION',
          hint: '망설이는 사이사이',
          child: Text(
            '음 ·  ·  ·   잘 모르겠어.',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}

class _Example extends StatelessWidget {
  const _Example({
    required this.label,
    required this.hint,
    required this.child,
  });

  final String label;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(hint, style: AppTypography.caption),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _SolutionDots extends StatelessWidget {
  const _SolutionDots();

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
          children: [
            for (var index = 0; index < 3; index++)
              Container(
                width: index == 1 ? 14 : 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: index == 1
                      ? AppColors.accent
                      : AppColors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
