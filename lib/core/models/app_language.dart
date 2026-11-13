enum AppLanguage {
  korean('ko', 'ko_KR', '한국어', '🇰🇷'),
  english('en', 'en_US', 'English', '🇺🇸');

  const AppLanguage(this.code, this.speechLocaleId, this.label, this.flag);

  final String code;
  final String speechLocaleId;
  final String label;
  final String flag;

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.korean,
    );
  }
}

class LanguagePair {
  const LanguagePair({required this.source, required this.target});

  final AppLanguage source;
  final AppLanguage target;

  String get label => '${source.label} → ${target.label}';
  bool get isSameLanguage => source == target;
}
