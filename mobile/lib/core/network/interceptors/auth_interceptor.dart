import 'package:dio/dio.dart';

import 'dart:async';

import '../../storage/secure_storage.dart';
import '../api_endpoints.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.secureStorage,
    required this.dio,
    this.onSessionExpired,
    this.isSessionCurrent,
  });
  final void Function()? onSessionExpired;
  final bool Function()? isSessionCurrent;
  final SecureStorage secureStorage;
  final Dio dio;
  Future<String?>? _refreshing;
  bool _expired = false;
  bool get _current => isSessionCurrent?.call() ?? true;
  bool _publicAuth(RequestOptions request) => [
    ApiEndpoints.login,
    ApiEndpoints.register,
    ApiEndpoints.googleLogin,
    ApiEndpoints.refreshToken,
    '/auth/email-otp/request',
    '/auth/email-otp/verify',
    '/auth/password/reset',
  ].any((path) => request.path == path || request.uri.path == '/api$path');
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_publicAuth(options)) {
      options.headers.remove('Authorization');
    } else {
      final token = await secureStorage.getAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<String?> _refresh() async {
    try {
      final token = await secureStorage.getRefreshToken();
      final accessBefore = await secureStorage.getAccessToken();
      if (token == null || !_current) return null;
      final result = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': token},
      );
      final access = result.data?['token']?.toString() ?? '';
      final refresh = result.data?['refreshToken']?.toString() ?? '';
      if (access.isEmpty || refresh.isEmpty) return null;
      if (!_current ||
          await secureStorage.getRefreshToken() != token ||
          await secureStorage.getAccessToken() != accessBefore) {
        return null;
      }
      await secureStorage.saveTokens(
        accessToken: access,
        refreshToken: refresh,
      );
      return access;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (!_current) {
      handler.next(err);
      return;
    }
    if (err.response?.statusCode == 401 &&
        request.extra['authRetried'] == true) {
      await _expire(request);
      handler.next(err);
      return;
    }
    if (err.response?.statusCode != 401 ||
        _publicAuth(request) ||
        request.extra['authRetried'] == true) {
      handler.next(err);
      return;
    }
    try {
      final current = await secureStorage.getAccessToken();
      String? token;
      if (current != null &&
          request.headers['Authorization'] != 'Bearer $current') {
        token = current;
      } else {
        final inFlight = _refreshing ??= _refresh();
        try {
          token = await inFlight;
        } finally {
          if (identical(_refreshing, inFlight)) _refreshing = null;
        }
      }
      if (token == null || !_current) {
        if (_current) await _expire(request);
        handler.next(err);
        return;
      }
      // A multipart upload cannot safely replay its already-consumed stream.
      if (request.data is FormData || request.data is Stream) {
        handler.next(err);
        return;
      }
      request.extra['authRetried'] = true;
      request.headers['Authorization'] = 'Bearer $token';
      handler.resolve(await dio.fetch<dynamic>(request));
    } catch (_) {
      handler.next(err);
    }
  }

  Future<void> _expire(RequestOptions request) async {
    final current = await secureStorage.getAccessToken();
    if (!_current ||
        current != null &&
            request.headers['Authorization'] != 'Bearer $current') {
      return;
    }
    await secureStorage.deleteTokens();
    if (_current) _notifyExpired();
  }

  void _notifyExpired() {
    if (!_expired) {
      _expired = true;
      scheduleMicrotask(() {
        if (_current) onSessionExpired?.call();
      });
    }
  }
}
