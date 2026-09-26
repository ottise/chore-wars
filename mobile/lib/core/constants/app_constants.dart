import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'Chore Wars';

  /// Web builds are primarily used as a zero-setup UI preview. Pass
  /// `--dart-define=UI_PREVIEW=false` when connecting the web app to an API.
  static const bool uiPreview = bool.fromEnvironment(
    'UI_PREVIEW',
    defaultValue: kIsWeb,
  );

  static const String previewHouseId = 'preview-house';
  static const String previewSeasonId = 'preview-season';
  static const String previewOccurrenceId = 'preview-dishes';
  static const String previewChoreId = 'preview-dishes-template';
  static const String previewRedemptionId = 'preview-chore-pass';

  // For local development on Android emulator, use 10.0.2.2 instead of localhost
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5297/api',
  );
  static const String signalRBaseUrl = String.fromEnvironment(
    'SIGNALR_BASE_URL',
    defaultValue: 'http://10.0.2.2:5297/hubs',
  );
}
