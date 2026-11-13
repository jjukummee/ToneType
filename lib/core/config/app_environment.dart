import 'package:flutter/foundation.dart';

abstract final class AppEnvironment {
  static const crossLanguageEnabled = bool.fromEnvironment(
    'ENABLE_CROSS_LANGUAGE',
  );
  static const _apiUrl = String.fromEnvironment('TONETYPE_API_URL');
  static const _legacyApiUrl = String.fromEnvironment('PROSODY_API_URL');
  static const _allowInsecureApi = bool.fromEnvironment('ALLOW_INSECURE_API');

  static Uri apiBaseUri() {
    final configured = _apiUrl.trim().isNotEmpty
        ? _apiUrl.trim()
        : _legacyApiUrl.trim();
    final value = configured.isEmpty && !kReleaseMode
        ? 'http://127.0.0.1:8000'
        : configured;
    if (value.isEmpty) {
      throw StateError('TONETYPE_API_URL must be provided for release builds.');
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('TONETYPE_API_URL is not a valid absolute URL.');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw StateError('TONETYPE_API_URL must use HTTP or HTTPS.');
    }
    if (kReleaseMode && uri.scheme != 'https' && !_allowInsecureApi) {
      throw StateError(
        'Release builds require HTTPS. Use ALLOW_INSECURE_API only for local testing.',
      );
    }
    return uri;
  }
}
