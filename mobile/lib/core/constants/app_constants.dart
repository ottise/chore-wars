import 'package:flutter/foundation.dart';

class AppConstants {
  static void validateReleaseConfiguration() {
    if (!kReleaseMode) return;
    if (uiPreview) throw StateError('Release builds require UI_PREVIEW=false.');
    if (useSameOrigin) {
      if (!kIsWeb) throw StateError('USE_SAME_ORIGIN requires a web build.');
      validateWebOrigin(Uri.base);
      return;
    }
    for (final value in [
      const String.fromEnvironment('API_BASE_URL'),
      const String.fromEnvironment('SIGNALR_BASE_URL'),
    ]) {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw StateError(
          'Release requires explicit HTTPS API_BASE_URL and SIGNALR_BASE_URL.',
        );
      }
    }
  }

  static const String appName = 'Chore Wars';

  static const bool useSameOrigin = bool.fromEnvironment('USE_SAME_ORIGIN');

  static void validateWebOrigin(Uri origin) {
    final loopback = const [
      'localhost',
      '127.0.0.1',
      '[::1]',
      '::1',
    ].contains(origin.host);
    if (origin.host.isEmpty ||
        (origin.scheme != 'https' && !(origin.scheme == 'http' && loopback))) {
      throw StateError(
        'Shared web builds require HTTPS or local loopback HTTP.',
      );
    }
  }

  /// Web builds are primarily used as a zero-setup UI preview. Pass
  /// `--dart-define=UI_PREVIEW=false` when connecting the web app to an API.
  static const bool uiPreview = bool.fromEnvironment(
    'UI_PREVIEW',
    defaultValue: false,
  );

  static const String previewHouseId = 'preview-house';
  static const String previewSeasonId = 'preview-season';
  static const String previewOccurrenceId = 'preview-dishes';
  static const String previewChoreId = 'preview-dishes-template';
  static const String previewRedemptionId = 'preview-chore-pass';

  // For local development on Android emulator, use 10.0.2.2 instead of localhost
  // On web, use localhost
  static String get apiBaseUrl =>
      useSameOrigin && kIsWeb ? '${Uri.base.origin}/api' : configuredApiBaseUrl;
  static String get signalRBaseUrl => useSameOrigin && kIsWeb
      ? '${Uri.base.origin}/hubs'
      : configuredSignalRBaseUrl;

  static const String configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb
        ? 'http://localhost:5297/api'
        : 'http://10.0.2.2:5297/api',
  );
  static const String configuredSignalRBaseUrl = String.fromEnvironment(
    'SIGNALR_BASE_URL',
    defaultValue: kIsWeb
        ? 'http://localhost:5297/hubs'
        : 'http://10.0.2.2:5297/hubs',
  );
}
