import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tone_top_bar.dart';

class DefaultContextSettingsScreen extends StatelessWidget {
  const DefaultContextSettingsScreen({super.key});

  static const contexts = ['일상', '여행', '학교', '비즈니스', '개발'];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ToneStage(
      child: Column(
        children: [
          ToneTopBar(
            title: '대화 상황 기본값',
            subtitle: '새 대화를 시작할 때 먼저 선택되는 상황이에요.',
            onBack: () => popScreen(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < contexts.length; index++) ...[
                        ListTile(
                          title: Text(
                            contexts[index],
                            style: AppTypography.bodyStrong,
                          ),
                          trailing: controller.defaultContext == contexts[index]
                              ? const Icon(
                                  CupertinoIcons.checkmark_alt,
                                  color: AppColors.accent,
                                )
                              : null,
                          onTap: () =>
                              controller.setDefaultContext(contexts[index]),
                        ),
                        if (index < contexts.length - 1)
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
          ),
        ],
      ),
    );
  }
}

class TextSizeSettingsScreen extends StatelessWidget {
  const TextSizeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ToneStage(
      child: Column(
        children: [
          ToneTopBar(
            title: '텍스트 크기',
            subtitle: '번역 결과와 앱의 글자 크기를 조절해요.',
            onBack: () => popScreen(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 34, 22, 30),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('미리보기', style: AppTypography.caption),
                          const Spacer(),
                          Center(
                            child: Text.rich(
                              TextSpan(
                                style: AppTypography.displayTranslation,
                                children: const [
                                  TextSpan(text: '텍스트가 '),
                                  TextSpan(
                                    text: '이렇게',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(text: ' 보여요.'),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Text('가', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: controller.textScale,
                          min: 0.9,
                          max: 1.6,
                          divisions: 7,
                          activeColor: AppColors.accent,
                          onChanged: controller.setTextScale,
                        ),
                      ),
                      const Text(
                        '가',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${(controller.textScale * 100).round()}%',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AudioDataSettingsScreen extends StatelessWidget {
  const AudioDataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ToneStage(
      child: Column(
        children: [
          ToneTopBar(
            title: '음성 데이터 설정',
            subtitle: '마이크와 음성 데이터가 사용되는 방식을 관리해요.',
            onBack: () => popScreen(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
              children: [
                _ToggleCard(
                  title: '대화 오디오 저장',
                  description: '끄면 음성은 인식 후 즉시 삭제되고 텍스트만 저장돼요.',
                  value: controller.storeAudioSamples,
                  onChanged: controller.setStoreAudioSamples,
                ),
                const SizedBox(height: 12),
                _ToggleCard(
                  title: '인식 품질 개선 참여',
                  description: '익명화된 오류 정보만 사용하며 언제든 끌 수 있어요.',
                  value: controller.improveRecognition,
                  onChanged: controller.setImproveRecognition,
                ),
                const SizedBox(height: 20),
                const Text(
                  '음성은 인식과 말투 분석을 위해 ToneType 서버와 Google Speech-to-Text로 전송됩니다. '
                  '오디오 저장을 끄면 분석 직후 기기와 ToneType 서버에서 삭제됩니다.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyStrong),
                const SizedBox(height: 5),
                Text(description, style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class InformationScreen extends StatelessWidget {
  const InformationScreen({
    required this.title,
    required this.body,
    super.key,
    this.copyValue,
  });

  final String title;
  final String body;
  final String? copyValue;

  @override
  Widget build(BuildContext context) {
    return ToneStage(
      child: Column(
        children: [
          ToneTopBar(title: title, onBack: () => popScreen(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Text(body, style: AppTypography.body),
                ),
                if (copyValue != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: copyValue!));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('클립보드에 복사했어요.')),
                      );
                    },
                    icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                    label: Text(copyValue!),
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
