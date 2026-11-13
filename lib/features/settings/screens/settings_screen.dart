import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tone_top_bar.dart';
import '../../auth/screens/login_screen.dart';
import '../../dictionary/screens/personal_dictionary_screen.dart';
import 'kinetic_expression_settings_screen.dart';
import 'settings_detail_screens.dart';
import 'translation_language_settings_screen.dart';

const _supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.embedded = false,
    this.onHistoryRequested,
  });

  final bool embedded;
  final VoidCallback? onHistoryRequested;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final textSizeLabel = controller.textScale == 1
        ? '기본'
        : '${(controller.textScale * 100).round()}%';
    final expressionLabel = switch (controller.expressionMode) {
      'minimal' => 'Minimal',
      'immersive' => 'Immersive',
      _ => 'Standard',
    };
    return ToneStage(
      safeBottom: !embedded,
      child: Column(
        children: [
          ToneTopBar(
            title: '설정',
            onBack: embedded ? null : () => popScreen(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
              children: [
                _SettingsGroup(
                  title: '번역',
                  children: [
                    _SettingsRow(
                      label: '기본 번역 언어',
                      value: controller.languagePair.label,
                      onTap: () => pushScreen(
                        context,
                        const TranslationLanguageSettingsScreen(),
                      ),
                    ),
                    _SettingsRow(
                      label: '대화 상황 기본값',
                      value: controller.defaultContext,
                      onTap: () => pushScreen(
                        context,
                        const DefaultContextSettingsScreen(),
                      ),
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: '말투',
                  children: [
                    _SettingsRow(
                      label: '말투 표현',
                      value: expressionLabel,
                      onTap: () => pushScreen(
                        context,
                        const KineticExpressionSettingsScreen(),
                      ),
                    ),
                    _SettingsRow(
                      label: '동작 줄이기',
                      trailing: CupertinoSwitch(
                        value: controller.reduceMotion,
                        activeTrackColor: AppColors.accent,
                        onChanged: controller.setReduceMotion,
                      ),
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: '개인화',
                  children: [
                    _SettingsRow(
                      label: '내 단어',
                      value: '${controller.dictionary.length}개',
                      onTap: () =>
                          pushScreen(context, const PersonalDictionaryScreen()),
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: '접근성',
                  children: [
                    _SettingsRow(
                      label: '텍스트 크기',
                      value: textSizeLabel,
                      onTap: () =>
                          pushScreen(context, const TextSizeSettingsScreen()),
                    ),
                    _SettingsRow(
                      label: '고대비',
                      trailing: CupertinoSwitch(
                        value: controller.highContrast,
                        activeTrackColor: AppColors.accent,
                        onChanged: controller.setHighContrast,
                      ),
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: '개인정보',
                  children: [
                    _SettingsRow(
                      label: '대화 기록 관리',
                      onTap: onHistoryRequested ?? () => popScreen(context),
                    ),
                    _SettingsRow(
                      label: '대화 기록 모두 삭제',
                      destructive: true,
                      onTap: () => _clearHistory(context),
                    ),
                    _SettingsRow(
                      label: '음성 데이터 설정',
                      onTap: () =>
                          pushScreen(context, const AudioDataSettingsScreen()),
                    ),
                    _SettingsRow(
                      label: '개인정보 처리방침',
                      onTap: () => pushScreen(
                        context,
                        const InformationScreen(
                          title: '개인정보 처리방침',
                          body:
                              'ToneType은 음성 인식과 말투 분석을 위해 녹음된 음성을 설정된 ToneType API와 Google Speech-to-Text로 전송합니다. 현재 서버는 요청 처리 중 메모리에서만 음성을 사용하며 원본 파일을 영구 저장하지 않습니다. 오디오 저장을 켜면 원본은 사용자 기기에만 보관됩니다. 대화 기록, 기본 언어, 개인 사전과 접근성 설정은 기기에 저장되며 설정에서 삭제할 수 있습니다.',
                        ),
                      ),
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: '계정',
                  children: [
                    _SettingsRow(
                      label: controller.isGuest ? '로그인 없이 사용 중' : '로그인 계정',
                      value: controller.isGuest ? '기기 내 저장' : controller.email,
                    ),
                    _SettingsRow(
                      label: '로그아웃',
                      destructive: true,
                      onTap: () => _signOut(context),
                    ),
                  ],
                ),
                _SettingsGroup(
                  title: '앱 정보',
                  children: [
                    _SettingsRow(
                      label: 'ToneType 정보',
                      onTap: () => pushScreen(
                        context,
                        const InformationScreen(
                          title: 'ToneType 정보',
                          body:
                              'ToneType은 무엇을 말했는가뿐 아니라 어떻게 말했는가까지 번역합니다. 목소리의 크기, 속도, 강조와 망설임을 Kinetic Typography로 표현합니다.\n\nVoice becomes Typography.',
                        ),
                      ),
                    ),
                    const _VersionRow(),
                    if (_supportEmail.isNotEmpty)
                      _SettingsRow(
                        label: '문의하기',
                        onTap: () => pushScreen(
                          context,
                          const InformationScreen(
                            title: '문의하기',
                            body: '발견한 문제나 개선 의견을 알려주세요.',
                            copyValue: _supportEmail,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _signOut(BuildContext context) {
    AppScope.of(context, listen: false).signOut();
    Navigator.of(context).pushAndRemoveUntil<void>(
      CupertinoPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _clearHistory(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('대화 기록을 모두 삭제할까요?'),
        content: const Text('삭제한 기록은 복구할 수 없습니다.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      AppScope.of(context, listen: false).clearConversationHistory();
    }
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final value = info == null
            ? '확인 중'
            : '${info.version} (${info.buildNumber})';
        return _SettingsRow(label: '버전', value: value);
      },
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.caption),
          const SizedBox(height: 8),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index < children.length - 1)
                    const Divider(
                      height: 1,
                      indent: 16,
                      color: AppColors.separator,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 57),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyStrong.copyWith(
                  fontSize: 15,
                  color: destructive ? Colors.redAccent : AppColors.ink,
                ),
              ),
            ),
            _buildValue(),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.inkFaint,
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return Semantics(container: true, child: content);
    return Semantics(
      container: true,
      button: true,
      label: value == null ? label : '$label, $value',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }

  Widget _buildValue() {
    if (value != null) {
      return Flexible(
        child: Text(
          value!,
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption,
        ),
      );
    }
    return trailing ?? const SizedBox.shrink();
  }
}
