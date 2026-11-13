import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../conversation/screens/conversation_completed_screen.dart';
import '../../conversation/screens/conversation_screen.dart';
import '../../history/screens/conversation_history_screen.dart';
import '../../settings/screens/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex.clamp(0, 2);

  void _select(int index) => setState(() => _index = index);

  Future<void> _completeConversation() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => ConversationCompletedScreen(
          onFinish: () {
            Navigator.of(context).pop();
            _select(1);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_index) {
      0 => ConversationScreen(
        key: const ValueKey('translation-tab'),
        embedded: true,
        onConversationEnded: _completeConversation,
      ),
      1 => const ConversationHistoryScreen(
        key: ValueKey('history-tab'),
        embedded: true,
      ),
      _ => SettingsScreen(
        key: const ValueKey('settings-tab'),
        embedded: true,
        onHistoryRequested: () => _select(1),
      ),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: content,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        height: 72,
        elevation: 0,
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        indicatorColor: AppColors.accentSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(CupertinoIcons.mic),
            selectedIcon: Icon(CupertinoIcons.mic_fill),
            label: '번역',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.clock),
            selectedIcon: Icon(CupertinoIcons.clock_fill),
            label: '대화 기록',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.gear),
            selectedIcon: Icon(CupertinoIcons.gear_solid),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
