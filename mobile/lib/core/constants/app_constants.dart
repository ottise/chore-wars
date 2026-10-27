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
    for (final value in [configuredApiBaseUrl, configuredSignalRBaseUrl]) {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw StateError(
          'Release requires HTTPS API_BASE_URL and SIGNALR_BASE_URL.',
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

  /// Preview mode is opt-in and does not connect to the backend.
  static const bool uiPreview = bool.fromEnvironment(
    'UI_PREVIEW',
    defaultValue: false,
  );

  static const String previewHouseId = 'preview-house';
  static const String previewSeasonId = 'preview-season';
  static const String previewOccurrenceId = 'preview-dishes';
  static const String previewChoreId = 'preview-dishes-template';
  static const String previewRedemptionId = 'preview-chore-pass';

  // Override both URLs with dart-define when using a local backend.
  static String get apiBaseUrl =>
      useSameOrigin && kIsWeb ? '${Uri.base.origin}/api' : configuredApiBaseUrl;
  static String get signalRBaseUrl => useSameOrigin && kIsWeb
      ? '${Uri.base.origin}/hubs'
      : configuredSignalRBaseUrl;

  static const String configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://chore-wars-o3rm.onrender.com/api',
  );
  static const String configuredSignalRBaseUrl = String.fromEnvironment(
    'SIGNALR_BASE_URL',
    defaultValue: 'https://chore-wars-o3rm.onrender.com/hubs',
  );
}
