import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/state/app_scope.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tone_top_bar.dart';
import '../../auth/screens/login_screen.dart';
import '../../navigation/screens/main_shell.dart';
import 'onboarding_problem_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(AppMotion.splash, () {
      if (mounted) {
        final controller = AppScope.of(context, listen: false);
        final destination = !controller.hasSession
            ? const LoginScreen()
            : controller.onboardingComplete
            ? const MainShell()
            : const OnboardingProblemScreen();
        replaceScreen(context, destination);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToneStage(
      child: Stack(
        children: [
          const Center(child: _AnimatedWordmark()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                _RhythmBar(height: 12, opacity: 0.20),
                _RhythmBar(height: 20, opacity: 0.28),
                _RhythmBar(height: 30, opacity: 0.46, accent: true),
                _RhythmBar(height: 18, opacity: 0.25),
                _RhythmBar(height: 10, opacity: 0.18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedWordmark extends StatefulWidget {
  const _AnimatedWordmark();

  @override
  State<_AnimatedWordmark> createState() => _AnimatedWordmarkState();
}

class _AnimatedWordmarkState extends State<_AnimatedWordmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _settle = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.premiumCurve,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _settle,
      builder: (context, child) {
        final value = reduceMotion ? 1.0 : _settle.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x172F6BFF),
                        blurRadius: 32,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 56,
                        height: 1,
                        color: AppColors.ink,
                        letterSpacing: -2.2,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Tone',
                          style: TextStyle(fontWeight: FontWeight.w400),
                        ),
                        TextSpan(
                          text: 'Type',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '말의 뜻을 넘어, 말투까지.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.inkSoft,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RhythmBar extends StatelessWidget {
  const _RhythmBar({
    required this.height,
    required this.opacity,
    this.accent = false,
  });

  final double height;
  final double opacity;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: (accent ? AppColors.accent : AppColors.inkFaint).withValues(
          alpha: opacity,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
