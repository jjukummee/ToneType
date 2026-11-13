import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class LanguageSelectorTile extends StatelessWidget {
  const LanguageSelectorTile({
    required this.label,
    required this.language,
    required this.onTap,
    super.key,
  });

  final String label;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.84),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          width: double.infinity,
          height: 104,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: Colors.white),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.caption),
              const Spacer(),
              Row(
                children: [
                  Text(language.flag, style: const TextStyle(fontSize: 23)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(language.label, style: AppTypography.sectionTitle),
                  const Spacer(),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: AppColors.inkFaint,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<AppLanguage?> showAppLanguagePicker(BuildContext context) {
  return showModalBottomSheet<AppLanguage>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    isScrollControlled: true,
    builder: (context) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet();

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final available = AppLanguage.values.where(
      (language) => language.label.toLowerCase().contains(_query.toLowerCase()),
    );
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.54,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: const BoxDecoration(
          color: Color(0xFAFAFBFD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text('언어 선택', style: AppTypography.sectionTitle),
            const SizedBox(height: 16),
            CupertinoSearchTextField(
              placeholder: '언어 검색',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 16),
            for (final language in available)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  language.flag,
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(language.label, style: AppTypography.bodyStrong),
                onTap: () => Navigator.pop(context, language),
              ),
            const Spacer(),
            const Text(
              '같은 언어를 선택하면 말의 의미는 유지하면서 말투와 강조를 시각적으로 표현해요.',
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}
