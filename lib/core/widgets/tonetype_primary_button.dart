import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

class ToneTypePrimaryButton extends StatelessWidget {
  const ToneTypePrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.control),
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.accentTop, AppColors.accent],
                  )
                : null,
            color: enabled ? null : AppColors.ink.withValues(alpha: 0.08),
            boxShadow: enabled ? AppShadows.floating : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.white : AppColors.inkFaint,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
