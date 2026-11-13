import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tone_top_bar.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/conversation_record.dart';
import 'conversation_detail_screen.dart';

class ConversationHistoryScreen extends StatefulWidget {
  const ConversationHistoryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  bool _searching = false;
  bool _selecting = false;
  String _query = '';
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final records = _filtered(controller.conversationHistory);
    final groups = _group(records);
    return ToneStage(
      safeBottom: !widget.embedded,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                if (!widget.embedded)
                  IconButton(
                    tooltip: '뒤로',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(CupertinoIcons.chevron_left, size: 22),
                  )
                else
                  const SizedBox(width: 8),
                const Spacer(),
                if (_selecting)
                  TextButton(
                    onPressed: _cancelSelection,
                    child: const Text('취소'),
                  )
                else ...[
                  _HeaderAction(
                    icon: CupertinoIcons.search,
                    label: '검색',
                    onTap: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query = '';
                    }),
                  ),
                  if (controller.conversationHistory.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _HeaderAction(
                      icon: CupertinoIcons.checkmark_circle,
                      label: '기록 선택',
                      onTap: _beginSelection,
                    ),
                  ],
                ],
                if (!widget.embedded) ...[
                  const SizedBox(width: 6),
                  _HeaderAction(
                    icon: CupertinoIcons.gear,
                    label: '설정',
                    onTap: () => pushScreen(context, const SettingsScreen()),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selecting ? '${_selectedIds.length}개 선택' : '대화 기록',
                style: AppTypography.title,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _searching
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                    child: CupertinoSearchTextField(
                      autofocus: true,
                      placeholder: '대화 내용, 언어, 상황 검색',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: controller.conversationHistory.isEmpty
                ? const _EmptyHistory()
                : groups.isEmpty
                ? const Center(
                    child: Text('검색 결과가 없어요.', style: AppTypography.body),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
                    itemCount: groups.length,
                    itemBuilder: (context, index) => _HistoryGroupView(
                      group: groups[index],
                      selecting: _selecting,
                      selectedIds: _selectedIds,
                      onToggle: _toggleSelection,
                      onLongPress: (id) {
                        if (!_selecting) _beginSelection();
                        _toggleSelection(id);
                      },
                    ),
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _selecting
                ? _SelectionActionBar(
                    key: const ValueKey('history-selection-actions'),
                    selectedCount: _selectedIds.length,
                    onDelete: _selectedIds.isEmpty ? null : _deleteSelected,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  List<ConversationRecord> _filtered(List<ConversationRecord> records) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return records;
    return records
        .where(
          (record) =>
              record.languagePair.label.toLowerCase().contains(query) ||
              record.context.toLowerCase().contains(query) ||
              record.originalText.toLowerCase().contains(query) ||
              record.resultText.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _beginSelection() {
    setState(() {
      _selecting = true;
      _searching = false;
      _query = '';
    });
  }

  void _cancelSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    if (count == 0) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(count == 1 ? '이 기록을 삭제할까요?' : '$count개의 기록을 삭제할까요?'),
        content: const Text('삭제한 대화 기록은 복구할 수 없어요.'),
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
    if (confirmed != true || !mounted) return;
    AppScope.of(context, listen: false).deleteConversationRecords(_selectedIds);
    _cancelSelection();
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.waveform, color: AppColors.inkFaint, size: 30),
            SizedBox(height: 14),
            Text('아직 저장된 대화가 없어요.', style: AppTypography.bodyStrong),
            SizedBox(height: 6),
            Text(
              '음성 분석이나 직접 입력을 완료하면 이곳에 기록됩니다.',
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryGroupView extends StatelessWidget {
  const _HistoryGroupView({
    required this.group,
    required this.selecting,
    required this.selectedIds,
    required this.onToggle,
    required this.onLongPress,
  });

  final _HistoryGroup group;
  final bool selecting;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.label, style: AppTypography.caption),
          const SizedBox(height: 10),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                for (var index = 0; index < group.items.length; index++) ...[
                  _HistoryRow(
                    record: group.items[index],
                    selecting: selecting,
                    selected: selectedIds.contains(group.items[index].id),
                    onToggle: onToggle,
                    onLongPress: onLongPress,
                  ),
                  if (index < group.items.length - 1)
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.record,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onLongPress,
  });

  final ConversationRecord record;
  final bool selecting;
  final bool selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.055)
          : Colors.transparent,
      child: InkWell(
        onTap: () => selecting
            ? onToggle(record.id)
            : pushScreen(context, ConversationDetailScreen(record: record)),
        onLongPress: () => onLongPress(record.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selecting) ...[
                    Icon(
                      selected
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
                      size: 20,
                      color: selected ? AppColors.accent : AppColors.inkFaint,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(record.languagePair.label, style: AppTypography.caption),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      record.context,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accent,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!selecting)
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: AppColors.inkFaint,
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                record.resultText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyStrong.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(_recordMeta(record), style: AppTypography.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.selectedCount,
    required this.onDelete,
    super.key,
  });

  final int selectedCount;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(22, 8, 22, 14),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: Colors.white),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Text(
              selectedCount == 0 ? '삭제할 기록을 선택해주세요.' : '$selectedCount개 선택됨',
              style: AppTypography.bodyStrong.copyWith(fontSize: 14),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onDelete,
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                disabledForegroundColor: AppColors.inkFaint,
              ),
              icon: const Icon(CupertinoIcons.delete, size: 17),
              label: const Text('삭제'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton.filled(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.72),
          foregroundColor: AppColors.inkSoft,
          minimumSize: const Size.square(38),
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _HistoryGroup {
  const _HistoryGroup(this.label, this.items);

  final String label;
  final List<ConversationRecord> items;
}

List<_HistoryGroup> _group(List<ConversationRecord> records) {
  final buckets = <String, List<ConversationRecord>>{};
  for (final record in records) {
    final label = _groupLabel(record.createdAt);
    buckets.putIfAbsent(label, () => []).add(record);
  }
  return buckets.entries
      .map((entry) => _HistoryGroup(entry.key, entry.value))
      .toList(growable: false);
}

String _groupLabel(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  final days = today.difference(date).inDays;
  if (days == 0) return '오늘';
  if (days == 1) return '어제';
  if (days < 7) return '이번 주';
  return '${value.year}년 ${value.month}월';
}

String _recordMeta(ConversationRecord record) {
  final hour = record.createdAt.hour;
  final period = hour < 12 ? '오전' : '오후';
  final displayHour = hour == 0
      ? 12
      : hour > 12
      ? hour - 12
      : hour;
  final minute = record.createdAt.minute.toString().padLeft(2, '0');
  final duration = record.durationSeconds;
  if (duration == null) return '$period $displayHour:$minute';
  return '$period $displayHour:$minute · ${duration.ceil()}초';
}
