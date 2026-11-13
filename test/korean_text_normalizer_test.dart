import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/core/models/app_language.dart';
import 'package:tonetype/core/text/korean_text_normalizer.dart';
import 'package:tonetype/features/conversation/data/conversation_result_source.dart';

void main() {
  test('normalizes whitespace and punctuation', () {
    expect(
      KoreanTextNormalizer.normalize('  내일말고   오늘 해줘 .  '),
      '내일 말고 오늘 해 줘.',
    );
  });

  test('corrects common Korean spelling mistakes conservatively', () {
    expect(
      KoreanTextNormalizer.normalize('안되요.몇일 뒤에 뵈요? 어떻해 된 거예요?'),
      '안 돼요. 며칠 뒤에 봬요? 어떻게 된 거예요?',
    );
  });

  test('spaces dependent nouns and auxiliary expressions', () {
    expect(
      KoreanTextNormalizer.normalize('할수있어요. 한적없어요. 하지마.'),
      '할 수 있어요. 한 적 없어요. 하지 마.',
    );
  });

  test('preserves already-correct text and intentional ellipsis', () {
    expect(KoreanTextNormalizer.normalize('왠지 오늘은 괜찮아...'), '왠지 오늘은 괜찮아...');
  });

  test('restores Korean UTF-8 bytes exposed as hex markers', () {
    expect(
      KoreanTextNormalizer.normalize(
        '조금 <0xEC><0xB0><0x9D><0xEC><0xB0><0x9D>한데요.',
      ),
      '조금 찝찝한데요.',
    );
  });

  test(
    'same-language result preserves source and renders corrected text',
    () async {
      final result = await const SameLanguageConversationResultSource()
          .finalResult(
            recognizedText: '내일말고 오늘 해줘.',
            languagePair: const LanguagePair(
              source: AppLanguage.korean,
              target: AppLanguage.korean,
            ),
          );

      expect(result.originalText, '“내일말고 오늘 해줘.”');
      expect(result.finalTranslation, '내일 말고 오늘 해 줘.');
      expect(result.kineticPlan?.transcript, result.finalTranslation);
    },
  );

  test('non-Korean text is not rewritten by the result source', () async {
    final result = await const SameLanguageConversationResultSource()
        .finalResult(
          recognizedText: 'Please do it now.',
          languagePair: const LanguagePair(
            source: AppLanguage.english,
            target: AppLanguage.english,
          ),
        );

    expect(result.finalTranslation, 'Please do it now.');
  });
}
