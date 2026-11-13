import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/core/state/app_controller.dart';
import 'package:tonetype/core/state/app_scope.dart';
import 'package:tonetype/core/theme/app_theme.dart';
import 'package:tonetype/core/models/app_language.dart';
import 'package:tonetype/features/auth/screens/login_screen.dart';
import 'package:tonetype/features/conversation/screens/conversation_completed_screen.dart';
import 'package:tonetype/features/dictionary/screens/personal_dictionary_screen.dart';
import 'package:tonetype/features/history/screens/conversation_detail_screen.dart';
import 'package:tonetype/features/history/screens/conversation_history_screen.dart';
import 'package:tonetype/features/history/models/conversation_record.dart';
import 'package:tonetype/features/settings/screens/kinetic_expression_settings_screen.dart';
import 'package:tonetype/features/settings/screens/settings_screen.dart';
import 'package:tonetype/features/settings/screens/translation_language_settings_screen.dart';

void main() {
  final record = ConversationRecord.create(
    languagePair: const LanguagePair(
      source: AppLanguage.korean,
      target: AppLanguage.korean,
    ),
    context: '일상',
    originalText: '테스트 문장',
    resultText: '테스트 문장',
    createdAt: DateTime(2026, 8, 19, 16, 32),
  );
  final screens = <(String, Widget)>[
    ('login', const LoginScreen()),
    ('conversation completed', const ConversationCompletedScreen()),
    ('conversation history', const ConversationHistoryScreen()),
    ('conversation detail', ConversationDetailScreen(record: record)),
    ('personal dictionary', const PersonalDictionaryScreen()),
    ('kinetic expression settings', const KineticExpressionSettingsScreen()),
    ('settings', const SettingsScreen()),
    (
      'translation language settings',
      const TranslationLanguageSettingsScreen(),
    ),
  ];

  for (final entry in screens) {
    testWidgets('${entry.$1} renders at the Figma viewport', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AppScope(
          controller: AppController.memory(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: entry.$2,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
