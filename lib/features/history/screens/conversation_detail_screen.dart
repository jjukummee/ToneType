import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tone_top_bar.dart';
import '../../conversation/models/conversation_state.dart';
import '../../conversation/widgets/tone_analysis_sheet.dart';
import '../../conversation/kinetic/realtime/realtime_kinetic_types.dart';
import '../../conversation/widgets/realtime_kinetic_text.dart';
import '../models/conversation_record.dart';

class ConversationDetailScreen extends StatefulWidget {
  const ConversationDetailScreen({required this.record, super.key});

  final ConversationRecord record;

  @override
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final FlutterTts _tts = FlutterTts();

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _openActions() async {
    final action = await showModalBottomSheet<_DetailAction>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (_) => _ActionSheet(hasTone: widget.record.tone != null),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _DetailAction.tone:
        final tone = widget.record.tone;
        if (tone != null) await _showToneInfo(tone);
      case _DetailAction.copyResult:
        await Clipboard.setData(ClipboardData(text: widget.record.resultText));
        _showMessage('결과 문장을 복사했어요.');
      case _DetailAction.copyOriginal:
        await Clipboard.setData(
          ClipboardData(text: widget.record.originalText),
        );
        _showMessage('말한 문장을 복사했어요.');
      case _DetailAction.play:
        await _tts.setLanguage(
          widget.record.targetLanguage.speechLocaleId.replaceAll('_', '-'),
        );
        await _tts.setSpeechRate(0.46);
        await _tts.speak(widget.record.resultText);
    }
  }

  Future<void> _showToneInfo(ConversationToneSummary tone) {
    return showToneAnalysisSheet(context, tone);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return ToneStage(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 22, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: '뒤로',
                  onPressed: () => popScreen(context),
                  icon: const Icon(CupertinoIcons.chevron_left, size: 22),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              record.languagePair.label,
                              style: AppTypography.sectionTitle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ContextChip(label: record.context),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateLabel(record.createdAt),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
              children: [
                _DialoguePair(
                  original: record.originalText,
                  result: record.resultText,
                  emphasizedWord: record.tone?.emphasizedWord,
                  composition: record.kineticComposition,
                  onTap: _openActions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialoguePair extends StatelessWidget {
  const _DialoguePair({
    required this.original,
    required this.result,
    required this.onTap,
    this.emphasizedWord,
    this.composition = const [],
  });

  final String original;
  final String result;
  final String? emphasizedWord;
  final List<RealtimeKineticSegment> composition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final word = emphasizedWord;
    final match = word == null ? -1 : result.indexOf(word);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '말한 문장',
          style: AppTypography.caption.copyWith(letterSpacing: 0.5),
        ),
        const SizedBox(height: 7),
        Text(
          '“$original”',
          style: AppTypography.originalSpeech.copyWith(
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '분석 결과',
          style: AppTypography.caption.copyWith(letterSpacing: 0.5),
        ),
        const SizedBox(height: 7),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: composition.isNotEmpty
                  // A saved live session keeps the typography it was composed
                  // with, so the record reads the way it was spoken.
                  ? RealtimeKineticTranscript(segments: composition)
                  : match < 0
                  ? Text(
                      result,
                      style: AppTypography.sectionTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        style: AppTypography.sectionTitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(text: result.substring(0, match)),
                          TextSpan(
                            text: word!,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(text: result.substring(match + word.length)),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.accent,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

enum _DetailAction { tone, copyResult, copyOriginal, play }

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.hasTone});

  final bool hasTone;

  @override
  Widget build(BuildContext context) {
    final actions = <(_DetailAction, String, IconData)>[
      if (hasTone)
        const (_DetailAction.tone, '말투 정보 보기', CupertinoIcons.waveform),
      const (_DetailAction.copyResult, '결과 문장 복사', CupertinoIcons.doc_on_doc),
      const (_DetailAction.copyOriginal, '말한 문장 복사', CupertinoIcons.doc_on_doc),
      const (_DetailAction.play, '문장 듣기', CupertinoIcons.play),
    ];
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        decoration: const BoxDecoration(
          color: Color(0xFAFAFBFD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            for (final action in actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(action.$3, size: 20, color: AppColors.inkSoft),
                title: Text(action.$2, style: AppTypography.bodyStrong),
                onTap: () => Navigator.pop(context, action.$1),
              ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  final hour = value.hour;
  final period = hour < 12 ? '오전' : '오후';
  final displayHour = hour == 0
      ? 12
      : hour > 12
      ? hour - 12
      : hour;
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}년 ${value.month}월 ${value.day}일 $period $displayHour:$minute';
}
