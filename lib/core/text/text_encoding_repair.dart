import 'dart:convert';

/// Repairs UTF-8 bytes that were accidentally exposed as `<0xEC>` markers.
///
/// Only valid multi-byte UTF-8 runs are replaced so a user intentionally
/// entering an ASCII marker is left untouched.
abstract final class TextEncodingRepair {
  static final RegExp _markerRun = RegExp(
    r'(?:<0x[0-9A-Fa-f]{2}>){2,}',
    caseSensitive: false,
  );
  static final RegExp _marker = RegExp(
    r'<0x([0-9A-Fa-f]{2})>',
    caseSensitive: false,
  );

  static String restoreUtf8ByteMarkers(String input) {
    if (!input.contains('<0x') && !input.contains('<0X')) return input;
    return input.replaceAllMapped(_markerRun, (run) {
      final source = run.group(0)!;
      final bytes = _marker
          .allMatches(source)
          .map((match) => int.parse(match.group(1)!, radix: 16))
          .toList(growable: false);
      if (!bytes.any((byte) => byte >= 0x80)) return source;
      try {
        final restored = utf8.decode(bytes, allowMalformed: false);
        if (restored.runes.any(
          (rune) => rune < 0x20 && rune != 0x09 && rune != 0x0a && rune != 0x0d,
        )) {
          return source;
        }
        return restored;
      } on FormatException {
        return source;
      }
    });
  }
}
