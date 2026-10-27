import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/app_error_fallback.dart';

class AppErrorReporter {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static const _noticeInterval = Duration(seconds: 5);
  static DateTime? _lastNotice;

  static void install() {
    ErrorWidget.builder = (_) => const AppErrorFallback();
    FlutterError.onError = (details) {
      if (kDebugMode) {
        FlutterError.presentError(details);
      } else {
        debugPrint('UI error: ${details.exception.runtimeType}');
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      final now = DateTime.now();
      if (_lastNotice == null ||
          now.difference(_lastNotice!) >= _noticeInterval) {
        _lastNotice = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          messengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Something went wrong. Please try again.'),
            ),
          );
        });
        WidgetsBinding.instance.scheduleFrame();
      }
      return true;
    };
  }

  static void report(Object error, StackTrace stack) =>
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
}
