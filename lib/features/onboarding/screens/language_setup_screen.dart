import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/models/app_language.dart';
import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tone_top_bar.dart';
import '../../../core/widgets/tonetype_primary_button.dart';
import 'conversation_context_screen.dart';

class LanguageSetupScreen extends StatefulWidget {
  const LanguageSetupScreen({super.key});

  @override
  State<LanguageSetupScreen> createState() => _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends State<LanguageSetupScreen> {
  AppLanguage? _source;
  AppLanguage? _target;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    _source ??= controller.sourceLanguage;
    _target ??= controller.targetLanguage;
  }

  void _swap() {
    setState(() {
      final previousSource = _source;
      _source = _target;
      _target = previousSource;
    });
  }

  Future<void> _pick({required bool source}) async {
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

  void _continue() {
    AppScope.of(
      context,
      listen: false,
    ).setLanguagePair(source: _source!, target: _target!);
    pushScreen(context, const ConversationContextScreen());
  }

  @override
  Widget build(BuildContext context) {
    return ToneStage(
      child: Column(
        children: [
          ToneTopBar(
            title: '어떤 언어로 대화할까요?',
            subtitle: _source == _target
                ? '같은 언어의 말투와 강조도 더 선명하게 보여드려요.'
                : '대화 중에는 서로의 말을 자동으로 번역해드려요.',
            onBack: () => popScreen(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LanguageSelectorTile(
                          label: '말하는 언어',
                          language: _source!,
                          onTap: () => _pick(source: true),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        LanguageSelectorTile(
                          label: '표현할 언어',
                          language: _target!,
                          onTap: () => _pick(source: false),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 22,
                      child: Semantics(
                        button: true,
                        label: '언어 바꾸기',
                        child: IconButton.filled(
                          onPressed: _swap,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.accent,
                            elevation: 3,
                            shadowColor: AppColors.ink.withValues(alpha: 0.2),
                          ),
                          icon: const Icon(CupertinoIcons.arrow_up_arrow_down),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: ToneTypePrimaryButton(label: '다음', onPressed: _continue),
          ),
        ],
      ),
    );
  }
}
