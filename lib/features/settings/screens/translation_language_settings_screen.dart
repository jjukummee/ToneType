import 'package:flutter/cupertino.dart';

import '../../../core/models/app_language.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tone_top_bar.dart';
import '../../../core/widgets/tonetype_primary_button.dart';

class TranslationLanguageSettingsScreen extends StatefulWidget {
  const TranslationLanguageSettingsScreen({super.key});

  @override
  State<TranslationLanguageSettingsScreen> createState() =>
      _TranslationLanguageSettingsScreenState();
}

class _TranslationLanguageSettingsScreenState
    extends State<TranslationLanguageSettingsScreen> {
  AppLanguage? _source;
  AppLanguage? _target;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    _source ??= controller.sourceLanguage;
    _target ??= controller.targetLanguage;
  }

  Future<void> _pick(bool source) async {
    final selected = await showAppLanguagePicker(context);
    if (selected == null || !mounted) return;
    setState(() {
      if (source) {
        _source = selected;
      } else {
        _target = selected;
      }
    });
  }

  void _save() {
    AppScope.of(
      context,
      listen: false,
    ).setLanguagePair(source: _source!, target: _target!);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sameLanguage = _source == _target;
    return ToneStage(
      child: Column(
        children: [
          ToneTopBar(
            title: '번역 언어',
            subtitle: '새 대화를 시작할 때 사용할 기본 언어를 설정해요.',
            onBack: () => popScreen(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 32, 22, 24),
              children: [
                LanguageSelectorTile(
                  label: '말하는 언어',
                  language: _source!,
                  onTap: () => _pick(true),
                ),
                const SizedBox(height: AppSpacing.sm),
                LanguageSelectorTile(
                  label: '표현할 언어',
                  language: _target!,
                  onTap: () => _pick(false),
                ),
                const SizedBox(height: 20),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (sameLanguage ? AppColors.accent : AppColors.ink)
                        .withValues(alpha: sameLanguage ? 0.08 : 0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        sameLanguage
                            ? CupertinoIcons.textformat_alt
                            : CupertinoIcons.arrow_right_arrow_left,
                        size: 19,
                        color: sameLanguage
                            ? AppColors.accent
                            : AppColors.inkSoft,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sameLanguage
                              ? '한국어 → 한국어에서는 뜻을 바꾸지 않고 목소리의 강조·속도·망설임을 글자로 표현해요.'
                              : AppEnvironment.crossLanguageEnabled
                              ? '서로 다른 언어에서는 의미 번역과 말투 표현을 함께 제공해요.'
                              : '서로 다른 언어 번역은 아직 연결되지 않아 저장할 수 없어요.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: ToneTypePrimaryButton(
              label: '저장',
              onPressed: sameLanguage || AppEnvironment.crossLanguageEnabled
                  ? _save
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
