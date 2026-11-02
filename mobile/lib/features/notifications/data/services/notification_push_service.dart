import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationPushService {
  NotificationPushService(this._dio, this._getAccessToken);

  final Dio _dio;
  final Future<String?> Function() _getAccessToken;
  StreamSubscription<String>? _tokenSubscription;
  bool _disposed = false;

  Future<void> register() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || _disposed) {
      return;
    }

    try {
      final accessToken = await _getAccessToken();
      if (_disposed || accessToken == null || accessToken.isEmpty) return;

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (_disposed ||
          (settings.authorizationStatus != AuthorizationStatus.authorized &&
              settings.authorizationStatus != AuthorizationStatus.provisional)) {
        return;
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) await _registerTokenSafely(token);
      _tokenSubscription ??= messaging.onTokenRefresh.listen((token) {
        if (!_disposed) _registerTokenSafely(token);
      });
    } catch (error) {
      // Keep Firebase setup failures from interrupting the signed-in app.
      debugPrint('Push notification setup failed: $error');
    }
  }

  Future<void> _registerTokenSafely(String token) async {
    try {
      await _dio.post(
        '/push-devices',
        data: {'token': token, 'platform': 'ANDROID'},
      );
    } catch (error) {
      // Push registration is optional; it must not prevent normal app use.
      debugPrint('Push device registration failed: $error');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }
}
