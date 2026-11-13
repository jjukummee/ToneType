import 'text_encoding_repair.dart';

/// Applies conservative, deterministic Korean spelling and spacing rules.
///
/// This is intentionally local and side-effect free: it never sends user text
/// to an external spelling service. The original transcript should be kept by
/// the caller while this normalized value is used for the displayed result.
abstract final class KoreanTextNormalizer {
  static String normalize(String input) {
    var text = TextEncodingRepair.restoreUtf8ByteMarkers(
      input,
    ).replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return text;

    for (final rule in _spellingRules) {
      text = text.replaceAll(rule.$1, rule.$2);
    }

    for (final rule in _spacingRules) {
      text = text.replaceAll(rule.$1, rule.$2);
    }

    for (final rule in _patternRules) {
      text = text.replaceAllMapped(rule.$1, (match) => rule.$2(match));
    }

    return text
        .replaceAllMapped(RegExp(r'\s+([,.!?…:;])'), (match) => match[1]!)
        .replaceAllMapped(
          RegExp(r'([,.!?;:])(?=[가-힣A-Za-z])'),
          (match) => '${match[1]} ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const List<(String, String)> _spellingRules = [
    ('않되', '안 되'),
    ('않돼', '안 돼'),
    ('안되요', '안 돼요'),
    ('안돼요', '안 돼요'),
    ('되요', '돼요'),
    ('됬', '됐'),
    ('뵈요', '봬요'),
    ('어떻해', '어떻게'),
    ('몇일', '며칠'),
    ('금새', '금세'),
    ('오랫만', '오랜만'),
    ('왠일', '웬일'),
    ('어의없', '어이없'),
    ('어의가 없', '어이가 없'),
    ('희안', '희한'),
    ('일일히', '일일이'),
    ('깨끗히', '깨끗이'),
    ('곰곰히', '곰곰이'),
    ('역활', '역할'),
    ('설레임', '설렘'),
    ('할께', '할게'),
    ('갈께', '갈게'),
    ('볼께', '볼게'),
    ('줄께', '줄게'),
  ];

  static const List<(String, String)> _spacingRules = [
    ('해주세요', '해 주세요'),
    ('해줘', '해 줘'),
    ('해줄', '해 줄'),
    ('하지마', '하지 마'),
    ('안돼', '안 돼'),
    ('안되', '안 되'),
    ('내일말고', '내일 말고'),
    ('오늘말고', '오늘 말고'),
    ('그거말고', '그거 말고'),
    ('이거말고', '이거 말고'),
    ('나말고', '나 말고'),
    ('너말고', '너 말고'),
    ('것같', '것 같'),
    ('거같', '거 같'),
    ('줄알', '줄 알'),
  ];

  static final List<(RegExp, String Function(Match))> _patternRules = [
    (
      RegExp(r'(할|갈|올|볼|될|줄|쓸|낼|날|살|탈|둘|받을|먹을|읽을)\s*수\s*(있|없)'),
      (match) => '${match[1]} 수 ${match[2]}',
    ),
    (RegExp(r'(한|본|간|온)\s*적\s*(있|없)'), (match) => '${match[1]} 적 ${match[2]}'),
    (RegExp(r'(할|될|갈|올|볼|알|줄|쓸|낼|날|살|탈)\s*것'), (match) => '${match[1]} 것'),
    (RegExp(r'(할|될|갈|올|볼|알|줄|쓸|낼|날|살|탈)\s*뿐'), (match) => '${match[1]} 뿐'),
  ];
}
