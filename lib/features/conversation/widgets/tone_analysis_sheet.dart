import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../models/conversation_state.dart';
import '../models/prosody_result.dart';

Future<void> showToneAnalysisSheet(
  BuildContext context,
  ConversationToneSummary tone,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (_) => _ToneAnalysisSheet(tone: tone),
  );
}

class _ToneAnalysisSheet extends StatelessWidget {
  const _ToneAnalysisSheet({required this.tone});

  final ConversationToneSummary tone;

  @override
  Widget build(BuildContext context) {
    final sentenceFirst = tone.analysisMode == ToneAnalysisMode.sentenceFocused;
    final words = [...tone.wordInsights]
      ..sort((a, b) => b.emphasis.compareTo(a.emphasis));
    final visibleWords = sentenceFirst ? words.take(3) : words;
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAFBFD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sentenceFirst ? '문장별 말투 지도' : '단어별 말투 해부',
                            style: AppTypography.sectionTitle,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            sentenceFirst
                                ? '문장마다 달라진 강조와 리듬을 나눠 봤어요.'
                                : '각 단어에 실린 힘과 높낮이, 쉼을 비교했어요.',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark, size: 18),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
                  children: [
                    _DeliverySummary(tone: tone),
                    const SizedBox(height: 14),
                    _OverviewMetrics(tone: tone),
                    const SizedBox(height: 26),
                    if (sentenceFirst) ...[
                      _SentenceSection(sentences: tone.sentenceInsights),
                      const SizedBox(height: 26),
                      _WordSection(words: visibleWords.toList(), compact: true),
                    ] else ...[
                      _WordSection(words: visibleWords.toList()),
                      const SizedBox(height: 26),
                      _SentenceSection(
                        sentences: tone.sentenceInsights,
                        compact: true,
                      ),
                    ],
                    if (tone.wordInsights.isEmpty &&
                        tone.sentenceInsights.isEmpty)
                      const _LegacyAnalysisNotice(),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: const Text(
                        '수치는 이 음성 안에서 비교한 상대값입니다. 말의 전달 방식을 설명하며 감정이나 의도를 단정하지 않아요.',
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliverySummary extends StatelessWidget {
  const _DeliverySummary({required this.tone});

  final ConversationToneSummary tone;

  @override
  Widget build(BuildContext context) {
    final summary = tone.deliverySummary.isNotEmpty
        ? tone.deliverySummary
        : _fallbackSummary(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.waveform, size: 15, color: AppColors.accent),
              SizedBox(width: 7),
              Text(
                '한눈에 들린 전달 방식',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(summary, style: AppTypography.bodyStrong.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _OverviewMetrics extends StatelessWidget {
  const _OverviewMetrics({required this.tone});

  final ConversationToneSummary tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: '음량',
                value: _levelLabel(tone.volume),
                score: tone.volume,
                icon: CupertinoIcons.speaker_2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: '음높이',
                value: tone.pitch == null ? '측정 없음' : _levelLabel(tone.pitch!),
                score: tone.pitch,
                icon: CupertinoIcons.waveform_path,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: '속도',
                value: tone.speed == null ? '측정 없음' : _speedLabel(tone.speed!),
                score: tone.speed,
                icon: CupertinoIcons.speedometer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: '쉼',
                value: _pauseLabel(tone.pause),
                score: tone.pause,
                icon: CupertinoIcons.pause,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.score,
    required this.icon,
  });

  final String label;
  final String value;
  final double? score;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Text(label, style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.bodyStrong),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: score ?? 0,
              color: score == null ? AppColors.inkFaint : AppColors.accent,
              backgroundColor: AppColors.ink.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceSection extends StatelessWidget {
  const _SentenceSection({required this.sentences, this.compact = false});

  final List<ToneSentenceInsight> sentences;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (sentences.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: '문장별 핵심',
          subtitle: '문장이 바뀔 때 강조와 끝맺음이 어떻게 달라졌는지 보여줘요.',
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < sentences.length; index++) ...[
          _SentenceCard(
            index: index,
            sentence: sentences[index],
            compact: compact,
          ),
          if (index < sentences.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    required this.index,
    required this.sentence,
    required this.compact,
  });

  final int index;
  final ToneSentenceInsight sentence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sentence.text,
                  style: AppTypography.bodyStrong.copyWith(height: 1.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sentence.coreSummary,
            style: AppTypography.body.copyWith(
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SignalChip(label: '음량 ${_levelLabel(sentence.volume)}'),
                _SignalChip(
                  label:
                      '속도 ${sentence.speed == null ? '측정 없음' : _speedLabel(sentence.speed!)}',
                ),
                _SignalChip(
                  label: '끝맺음 ${_intonationLabel(sentence.intonation)}',
                ),
                if (sentence.peakWord != null)
                  _SignalChip(label: '핵심어 ${sentence.peakWord}', accent: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WordSection extends StatelessWidget {
  const _WordSection({required this.words, this.compact = false});

  final List<ToneWordInsight> words;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: compact ? '두드러진 단어' : '핵심 단어 상세',
          subtitle: compact
              ? '전체 문장 중 강조 신호가 컸던 단어예요.'
              : '강조도가 높은 순서로 음량·음높이·길이·쉼을 비교했어요.',
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < words.length; index++) ...[
          _WordCard(word: words[index], rank: index + 1, compact: compact),
          if (index < words.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.word,
    required this.rank,
    required this.compact,
  });

  final ToneWordInsight word;
  final int rank;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: rank == 1
            ? AppColors.accent.withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(
          color: rank == 1
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.ink.withValues(alpha: 0.055),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '“${word.text}”',
                style: AppTypography.sectionTitle.copyWith(
                  color: rank == 1 ? AppColors.accent : AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                '${word.start.toStringAsFixed(1)}–${word.end.toStringAsFixed(1)}초',
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            _wordExplanation(word),
            style: AppTypography.body.copyWith(
              color: AppColors.inkSoft,
              height: 1.45,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SignalChip(label: '강조 ${(word.emphasis * 100).round()}%'),
                _SignalChip(label: '음량 ${_levelLabel(word.loudness)}'),
                _SignalChip(
                  label:
                      '음높이 ${word.pitch == null ? '측정 없음' : _levelLabel(word.pitch!)}',
                ),
                _SignalChip(label: '길이 ${word.duration.toStringAsFixed(2)}초'),
                if (word.pauseAfter >= 0.12)
                  _SignalChip(
                    label: '뒤 쉼 ${word.pauseAfter.toStringAsFixed(2)}초',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.accentSoft
            : AppColors.ink.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent ? AppColors.accent : AppColors.inkSoft,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.bodyStrong),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTypography.caption),
      ],
    );
  }
}

class _LegacyAnalysisNotice extends StatelessWidget {
  const _LegacyAnalysisNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Text(
        '이 기록은 세부 분석 기능이 추가되기 전에 저장되어 전체 말투 정보만 확인할 수 있어요.',
        style: AppTypography.caption,
      ),
    );
  }
}

String _wordExplanation(ToneWordInsight word) {
  final parts = <String>[];
  if (word.emphasis >= 0.72) {
    parts.add('주변 단어보다 힘이 뚜렷하게 실렸어요');
  } else if (word.emphasis >= 0.45) {
    parts.add('문장 안에서 보조 강조로 들렸어요');
  } else {
    parts.add('힘을 덜어 연결하는 단어로 들렸어요');
  }
  if (word.loudness >= 0.7) {
    parts.add('음량이 크게 올라갔어요');
  } else if (word.loudness < 0.32) {
    parts.add('주변보다 조용하게 말했어요');
  }
  if (word.pitch case final pitch?) {
    if (pitch >= 0.72) {
      parts.add('음높이가 높은 편이에요');
    } else if (pitch < 0.3) {
      parts.add('음높이를 낮춰 말했어요');
    }
  }
  if (word.pauseAfter >= 0.35) {
    parts.add('뒤에 긴 쉼을 두어 경계를 만들었어요');
  } else if (word.duration >= 0.55) {
    parts.add('비교적 길게 늘여 말했어요');
  }
  return '${parts.join(' · ')}.';
}

String _fallbackSummary(ConversationToneSummary tone) {
  final emphasis = tone.emphasizedWord == null
      ? ''
      : ' “${tone.emphasizedWord}”의 강조가 가장 선명했어요.';
  return '${_levelLabel(tone.volume)} 음량, '
      '${tone.speed == null ? '측정되지 않은' : _speedLabel(tone.speed!)} 속도, '
      '${_intonationLabel(tone.intonation)} 억양으로 전달했어요.$emphasis';
}

String _levelLabel(double value) {
  if (value >= 0.67) return '높음';
  if (value >= 0.34) return '보통';
  return '낮음';
}

String _speedLabel(double value) {
  if (value >= 0.67) return '빠름';
  if (value >= 0.34) return '보통';
  return '느림';
}

String _pauseLabel(double value) {
  if (value >= 0.5) return '많음';
  if (value >= 0.22) return '보통';
  return '짧음';
}

String _intonationLabel(ProsodyIntonation value) => switch (value) {
  ProsodyIntonation.rising => '상승',
  ProsodyIntonation.falling => '하강',
  ProsodyIntonation.flat => '평탄',
  ProsodyIntonation.unknown => '측정 없음',
};
