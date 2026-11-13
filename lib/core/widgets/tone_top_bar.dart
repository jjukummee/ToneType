import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class ToneTopBar extends StatelessWidget {
  const ToneTopBar({
    required this.title,
    super.key,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                if (onBack != null)
                  Semantics(
                    button: true,
                    label: '뒤로',
                    child: IconButton(
                      onPressed: onBack,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      icon: const Icon(
                        CupertinoIcons.chevron_left,
                        size: 22,
                        color: AppColors.ink,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 40),
                const Spacer(),
                ...actions,
              ],
            ),
          ),
          Text(title, style: AppTypography.title),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(subtitle!, style: AppTypography.body),
          ],
        ],
      ),
    );
  }
}

void popScreen(BuildContext context) => Navigator.of(context).pop();

Future<T?> pushScreen<T>(BuildContext context, Widget screen) {
  return Navigator.of(
    context,
  ).push<T>(CupertinoPageRoute<T>(builder: (_) => screen));
}

Future<T?> replaceScreen<T>(BuildContext context, Widget screen) {
  return Navigator.of(
    context,
  ).pushReplacement<T, void>(CupertinoPageRoute<T>(builder: (_) => screen));
}
