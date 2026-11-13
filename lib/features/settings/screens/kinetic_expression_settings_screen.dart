import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tone_top_bar.dart';
import '../../conversation/models/kinetic_segment.dart';
import '../../conversation/widgets/kinetic_text.dart';

class KineticExpressionSettingsScreen extends StatefulWidget {
  const KineticExpressionSettingsScreen({super.key});

  @override
  State<KineticExpressionSettingsScreen> createState() =>
      _KineticExpressionSettingsScreenState();
}

class _KineticExpressionSettingsScreenState
    extends State<KineticExpressionSettingsScreen> {
  KineticExpressionMode _mode = KineticExpressionMode.standard;
  bool _reduceMotion = false;
  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    final controller = AppScope.of(context);
    _mode = switch (controller.expressionMode) {
      'minimal' => KineticExpressionMode.minimal,
      'immersive' => KineticExpressionMode.immersive,
      _ => KineticExpressionMode.standard,
    };
    _reduceMotion = controller.reduceMotion;
    _restored = true;
  }

  void _selectMode(KineticExpressionMode mode) {
    setState(() => _mode = mode);
    AppScope.of(context, listen: false).setExpressionMode(mode.name);
  }

  void _setReducedMotion(bool value) {
    setState(() => _reduceMotion = value);
    AppScope.of(context, listen: false).setReduceMotion(value);
  }

  String get _description => switch (_mode) {
    KineticExpressionMode.minimal => '크기와 굵기로만 표현해요.',
    KineticExpressionMode.standard => '자연스럽고 짧은 움직임을 더해요.',
    KineticExpressionMode.immersive => '리듬과 움직임을 더 살려요.',
  };

  @override
  Widget build(BuildContext context) {
    return ToneStage(
      child: Column(
        children: [
          ToneTopBar(
            title: '말투 표현',
            subtitle: '글자가 움직이는 정도를 원하는 만큼 조절할 수 있어요.',
            onBack: () => popScreen(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
              children: [
                Container(
                  height: 230,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('미리보기', style: AppTypography.caption),
                      const Spacer(),
                      Center(
                        child: MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(disableAnimations: _reduceMotion),
                          child: KineticText(
                            key: ValueKey('$_mode-$_reduceMotion'),
                            mode: _mode,
                            plan: const KineticPlan(
                              mode: KineticGenerationMode.basic,
                              pattern: KineticPattern.surprise,
                              layout: KineticLayout.inline,
                              segments: [
                                KineticSegment(
                                  text: '정말?',
                                  motion: KineticMotion.rise,
                                  intensity: KineticIntensity.strong,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: Text(_description, style: AppTypography.caption),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Row(
                    children: [
                      for (final mode in KineticExpressionMode.values)
                        Expanded(
                          child: _ModeButton(
                            mode: mode,
                            selected: _mode == mode,
                            onTap: () => _selectMode(mode),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('동작 줄이기', style: AppTypography.bodyStrong),
                            SizedBox(height: 3),
                            Text(
                              '움직임 대신 크기·굵기로 표현해요.',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: _reduceMotion,
                        activeTrackColor: AppColors.accent,
                        onChanged: _setReducedMotion,
                      ),
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

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final KineticExpressionMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      KineticExpressionMode.minimal => 'Minimal',
      KineticExpressionMode.standard => 'Standard',
      KineticExpressionMode.immersive => 'Immersive',
    };
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x20202733),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.ink : AppColors.inkFaint,
            ),
          ),
        ),
      ),
    );
  }
}
