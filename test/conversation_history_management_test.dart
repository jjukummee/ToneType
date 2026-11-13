import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/core/models/app_language.dart';
import 'package:tonetype/core/state/app_controller.dart';
import 'package:tonetype/core/state/app_scope.dart';
import 'package:tonetype/core/theme/app_theme.dart';
import 'package:tonetype/features/history/models/conversation_record.dart';
import 'package:tonetype/features/history/screens/conversation_history_screen.dart';

void main() {
  ConversationRecord record(String id, String text) => ConversationRecord(
    id: id,
    createdAt: DateTime(2026, 8, 19, 14),
    sourceLanguage: AppLanguage.korean,
    targetLanguage: AppLanguage.korean,
    context: '일상',
    originalText: text,
    resultText: text,
  );

  test('controller deletes only selected conversation records', () {
    final controller = AppController.memory()
      ..addConversationRecord(record('first', '첫 번째'))
      ..addConversationRecord(record('second', '두 번째'));

    controller.deleteConversationRecords(const {'first'});

    expect(controller.conversationHistory, hasLength(1));
    expect(controller.conversationHistory.single.id, 'second');
  });

  testWidgets('history edit mode selects and deletes one record', (
    tester,
  ) async {
    final controller = AppController.memory()
      ..addConversationRecord(record('first', '첫 번째 기록'))
      ..addConversationRecord(record('second', '두 번째 기록'));
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ConversationHistoryScreen(embedded: true),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('기록 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('첫 번째 기록'));
    await tester.pumpAndSettle();
    expect(find.text('1개 선택'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    expect(find.text('이 기록을 삭제할까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '삭제'));
    await tester.pumpAndSettle();

    expect(controller.conversationHistory, hasLength(1));
    expect(controller.conversationHistory.single.id, 'second');
  });
}
