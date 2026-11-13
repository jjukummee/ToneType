import '../../../../core/text/korean_text_normalizer.dart';
import '../../models/prosody_result.dart';
import 'basic_kinetic_config.dart';
import 'basic_kinetic_types.dart';
import 'korean_kinetic_rules.dart';

class PhraseSegmenter {
  const PhraseSegmenter({this.config = const BasicKineticConfig()});

  final BasicKineticConfig config;

  List<PhraseUnit> segment({
    required String transcript,
    required ProsodyAnalysisResult prosody,
  }) {
    if (transcript.isEmpty) return const [];
    final words = _alignWords(transcript, prosody.segments);
    if (words.isEmpty) {
      return [
        PhraseUnit(text: transcript, words: const [], index: 0, isLast: true),
      ];
    }

    final groups = <List<AlignedWord>>[];
    var cursor = 0;
    while (cursor < words.length) {
      final ruleLength = _longestRuleAt(words, cursor);
      var length = ruleLength > 0 ? ruleLength : 1;
      if (ruleLength == 0 && !_mustStandAlone(words, cursor)) {
        while (length < config.maxPhraseWords &&
            cursor + length < words.length) {
          final previous = words[cursor + length - 1];
          final nextIndex = cursor + length;
          if (_isBoundaryAfter(previous, transcript, words[nextIndex]) ||
              _longestRuleAt(words, nextIndex) > 0 ||
              _mustStandAlone(words, nextIndex)) {
            break;
          }
          length++;
        }
      }
      groups.add(words.sublist(cursor, cursor + length));
      cursor += length;
    }

    // Text before the first measured word gets its own phrases instead of
    // being absorbed into the first one. A live session only keeps the most
    // recent audio, so the opening of a long utterance often has no word
    // timings at all — gluing it on would render most of the transcript as a
    // single undifferentiated block.
    final leadEnd = groups.first.first.transcriptStart;
    final parts = <(String, List<AlignedWord>)>[
      if (leadEnd > 0)
        for (final text in _textOnlyPhrases(transcript.substring(0, leadEnd)))
          (text, const []),
      for (var index = 0; index < groups.length; index++)
        (
          transcript.substring(
            groups[index].first.transcriptStart,
            index + 1 < groups.length
                ? groups[index + 1].first.transcriptStart
                : transcript.length,
          ),
          groups[index],
        ),
    ];

    return [
      for (var index = 0; index < parts.length; index++)
        PhraseUnit(
          text: parts[index].$1,
          words: parts[index].$2,
          index: index,
          isLast: index == parts.length - 1,
        ),
    ];
  }

  /// Splits text that has no measured audio into readable phrases.
  ///
  /// The slices tile the input exactly, so the transcript is never altered.
  List<String> _textOnlyPhrases(String text) {
    final matches = RegExp(r'\S+\s*').allMatches(text).toList();
    if (matches.isEmpty) return text.isEmpty ? const [] : [text];
    final output = <String>[];
    var start = 0;
    var count = 0;
    for (var index = 0; index < matches.length; index++) {
      count++;
      final isLast = index == matches.length - 1;
      final breaksHere =
          RegExp(r'[,.!?…~]\s*$').hasMatch(matches[index].group(0)!) ||
          count >= config.maxPhraseWords;
      if (!breaksHere && !isLast) continue;
      final end = isLast ? text.length : matches[index].end;
      output.add(text.substring(start, end));
      start = end;
      count = 0;
    }
    return output;
  }

  List<AlignedWord> _alignWords(
    String transcript,
    List<ProsodySegmentResult> segments,
  ) {
    final lower = transcript.toLowerCase();
    final output = <AlignedWord>[];
    var cursor = 0;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final raw = segment.text.trim();
      if (raw.isEmpty) continue;
      final stripped = raw.replaceAll(RegExp(r'[,.!?…~]+$'), '');
      final candidates = <String>{
        raw,
        if (stripped.isNotEmpty) stripped,
        KoreanTextNormalizer.normalize(raw),
        if (stripped.isNotEmpty) KoreanTextNormalizer.normalize(stripped),
      };
      var matchText = '';
      var match = -1;
      for (final candidate in candidates) {
        if (candidate.isEmpty) continue;
        final candidateMatch = lower.indexOf(candidate.toLowerCase(), cursor);
        if (candidateMatch >= 0) {
          matchText = candidate;
          match = candidateMatch;
          break;
        }
      }
      if (match < 0) continue;
      final end = match + matchText.length;
      output.add(
        AlignedWord(
          sourceIndex: index,
          text: transcript.substring(match, end),
          normalizedText: normalizeKoreanToken(matchText),
          transcriptStart: match,
          transcriptEnd: end,
          prosody: segment,
        ),
      );
      cursor = end;
    }
    return output;
  }

  int _longestRuleAt(List<AlignedWord> words, int index) {
    var best = 0;
    for (final rule in KoreanKineticRules.phraseSequences) {
      if (rule.length <= best || index + rule.length > words.length) continue;
      var matches = true;
      for (var offset = 0; offset < rule.length; offset++) {
        if (words[index + offset].normalizedText !=
            normalizeKoreanToken(rule[offset])) {
          matches = false;
          break;
        }
      }
      if (matches) best = rule.length;
    }
    return best;
  }

  bool _mustStandAlone(List<AlignedWord> words, int index) {
    final current = words[index].normalizedText;
    if (KoreanKineticRules.standalone.contains(current)) return true;
    if (_isDominantSpokenWord(words, index)) return true;
    final repeatsPrevious =
        index > 0 && words[index - 1].normalizedText == current;
    final repeatsNext =
        index + 1 < words.length && words[index + 1].normalizedText == current;
    return repeatsPrevious || repeatsNext;
  }

  bool _isDominantSpokenWord(List<AlignedWord> words, int index) {
    if (words.length < 2) return false;
    final emphasis = words[index].prosody.emphasis;
    if (emphasis < config.dominantWordEmphasis) return false;
    final others = [
      for (var wordIndex = 0; wordIndex < words.length; wordIndex++)
        if (wordIndex != index) words[wordIndex].prosody.emphasis,
    ];
    final strongestOther = others.reduce((a, b) => a > b ? a : b);
    final averageOther = others.reduce((a, b) => a + b) / others.length;
    return emphasis >= strongestOther &&
        emphasis - averageOther >= config.dominantWordEmphasisGap;
  }

  bool _isBoundaryAfter(AlignedWord word, String transcript, AlignedWord next) {
    if (word.prosody.pauseAfter >= config.phrasePauseBoundary) return true;
    final between = transcript.substring(
      word.transcriptEnd,
      next.transcriptStart,
    );
    return RegExp(r'[,!?…]').hasMatch(word.text + between);
  }
}
