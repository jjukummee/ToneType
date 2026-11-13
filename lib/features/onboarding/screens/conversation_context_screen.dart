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
import '../../conversation/screens/conversation_screen.dart';

class ConversationContextScreen extends StatefulWidget {
  const ConversationContextScreen({super.key});

  @override
  State<ConversationContextScreen> createState() =>
      _ConversationContextScreenState();
}

class _ConversationContextScreenState extends State<ConversationContextScreen> {
  String? _selected;
  final _customController = TextEditingController();
  bool _restored = false;

  static const _items = <(String, IconData)>[
    ('일상', CupertinoIcons.chat_bubble_2),
    ('여행', CupertinoIcons.briefcase),
    ('학교', CupertinoIcons.book),
    ('비즈니스', CupertinoIcons.person_2),
    ('개발', CupertinoIcons.chevron_left_slash_chevron_right),
    ('직접 입력', CupertinoIcons.add),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _selected = AppScope.of(context).defaultContext;
    _restored = true;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _start() {
    final controller = AppScope.of(context, listen: false);
    if (_selected != null && _selected != '직접 입력') {
      controller.setDefaultContext(_selected!);
    }
    controller.completeOnboarding();
    pushScreen(context, const ConversationScreen());
  }

  @override
  Widget build(BuildContext context) {
    return ToneStage(
      child: Column(
        children: [
          ToneTopBar(
            title: '어떤 대화를 시작하나요?',
            subtitle: '상황을 알려주면 조금 더 자연스럽게 알아들을 수 있어요.',
            onBack: () => popScreen(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.55,
                          ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final selected = _selected == item.$1;
                        return _ContextTile(
                          label: item.$1,
                          icon: item.$2,
                          selected: selected,
                          onTap: () => setState(() => _selected = item.$1),
                        );
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      child: _selected == '직접 입력'
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: CupertinoTextField(
                                controller: _customController,
                                placeholder: '예: 해외 디자인 컨퍼런스',
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.control,
                                  ),
                                  border: Border.all(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Column(
              children: [
                ToneTypePrimaryButton(
                  label: '대화 시작하기',
                  onPressed:
                      _selected == null ||
                          (_selected == '직접 입력' &&
                              _customController.text.trim().isEmpty)
                      ? null
                      : _start,
                ),
                TextButton(
                  onPressed: _start,
                  child: const Text(
                    '건너뛰고 시작하기',
                    style: TextStyle(color: AppColors.inkSoft),
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

class _ContextTile extends StatelessWidget {
  const _ContextTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: selected
                    ? AppColors.accent
                    : AppColors.ink.withValues(alpha: 0.06),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? AppColors.accent : AppColors.inkSoft,
                ),
                const SizedBox(width: 12),
                Text(label, style: AppTypography.bodyStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
