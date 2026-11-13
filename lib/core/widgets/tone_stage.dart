import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ToneStage extends StatelessWidget {
  const ToneStage({
    required this.child,
    super.key,
    this.safeTop = true,
    this.safeBottom = true,
  });

  final Widget child;
  final bool safeTop;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.05),
            radius: 1.25,
            colors: [AppColors.backgroundTint, AppColors.background],
            stops: [0, 0.62],
          ),
        ),
        child: SafeArea(top: safeTop, bottom: safeBottom, child: child),
      ),
    );
  }
}
