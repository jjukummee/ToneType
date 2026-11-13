import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tone_top_bar.dart';
import '../../../core/widgets/tonetype_primary_button.dart';

class PersonalDictionaryScreen extends StatefulWidget {
  const PersonalDictionaryScreen({super.key});

  @override
  State<PersonalDictionaryScreen> createState() =>
      _PersonalDictionaryScreenState();
}

class _PersonalDictionaryScreenState extends State<PersonalDictionaryScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final words = controller.dictionary;
    return ToneStage(
      child: Column(
        children: [
          ToneTopBar(
            title: '내 단어',
            subtitle: '내가 자주 쓰는 이름과 전문용어를 기기에 저장해 관리해요.',
            onBack: () => popScreen(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
              children: [
                Text('등록된 단어 ${words.length}', style: AppTypography.caption),
                const SizedBox(height: 10),
                if (words.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text('등록된 단어가 없어요.', style: AppTypography.body),
                    ),
                  )
                else
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      children: [
                        for (var index = 0; index < words.length; index++) ...[
                          _WordRow(
                            word: words[index],
                            onRemove: () =>
                                controller.removeDictionaryWord(words[index]),
                          ),
                          if (index < words.length - 1)
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
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: ToneTypePrimaryButton(
              label: '＋ 단어 추가',
              onPressed: () async {
                final word = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  barrierColor: AppColors.scrim,
                  builder: (_) => const _AddWordSheet(),
                );
                if (word != null && mounted) {
                  controller.addDictionaryWord(word);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.onRemove});

  final String word;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 57,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(child: Text(word, style: AppTypography.bodyStrong)),
          IconButton(
            tooltip: '$word 삭제',
            onPressed: onRemove,
            icon: const Icon(
              CupertinoIcons.xmark_circle_fill,
              color: AppColors.inkFaint,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _AddWordSheet extends StatefulWidget {
  const _AddWordSheet();

  @override
  State<_AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends State<_AddWordSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: const BoxDecoration(
          color: Color(0xFAFAFBFD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            const Text('단어 추가', style: AppTypography.sectionTitle),
            const SizedBox(height: 18),
            const Text('단어', style: AppTypography.caption),
            const SizedBox(height: 7),
            CupertinoTextField(
              controller: _controller,
              autofocus: true,
              placeholder: '예: ToneType',
              padding: const EdgeInsets.all(15),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('발음 또는 설명 (선택)', style: AppTypography.caption),
            const SizedBox(height: 7),
            const CupertinoTextField(
              placeholder: '예: 톤타입',
              padding: EdgeInsets.all(15),
            ),
            const SizedBox(height: 20),
            ToneTypePrimaryButton(
              label: '추가하기',
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, _controller.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}
