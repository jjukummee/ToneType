import 'package:flutter/material.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tonetype_primary_button.dart';
import '../../navigation/screens/main_shell.dart';
import '../../history/models/conversation_record.dart';

class ConversationCompletedScreen extends StatelessWidget {
  const ConversationCompletedScreen({super.key, this.onFinish});

  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final history = AppScope.of(context).conversationHistory;
    final latest = history.isEmpty ? null : history.first;
    return ToneStage(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 42, 22, 14),
        child: Column(
          children: [
            const Spacer(),
            const Text('대화를 마쳤어요.', style: AppTypography.title),
            const SizedBox(height: 12),
            const Text(
              '분석이 완료된 문장은 대화 기록에서 다시 볼 수 있어요.',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: 34),
            _SummaryCard(record: latest),
            const Spacer(flex: 2),
            ToneTypePrimaryButton(
              label: '대화 기록 보기',
              onPressed: () => _finish(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _finish(BuildContext context) {
    if (onFinish != null) {
      onFinish!();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const MainShell(initialIndex: 1)),
      (_) => false,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.record});

  final ConversationRecord? record;

  @override
  Widget build(BuildContext context) {
    final record = this.record;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Colors.white),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (record == null)
            const Text('이번 대화에서 완료된 분석이 없어요.', style: AppTypography.body)
          else ...[
            Text(
              '“${record.originalText}”',
              style: AppTypography.originalSpeech,
            ),
            const SizedBox(height: 9),
            Text(record.resultText, style: AppTypography.bodyStrong),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.separator),
            const SizedBox(height: AppSpacing.md),
            _StatRow(label: '언어', value: record.languagePair.label),
            if (record.durationSeconds != null)
              _StatRow(
                label: '음성 길이',
                value: '${record.durationSeconds!.ceil()}초',
              ),
            _StatRow(label: '상황', value: record.context),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: AppTypography.caption),
          const Spacer(),
          Text(value, style: AppTypography.bodyStrong.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}
