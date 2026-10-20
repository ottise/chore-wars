import 'package:dio/dio.dart';

import 'dart:async';

import '../../storage/secure_storage.dart';
import '../api_endpoints.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.secureStorage,
    required this.dio,
    this.onSessionExpired,
  });
  final void Function()? onSessionExpired;
  final SecureStorage secureStorage;
  final Dio dio;
  Future<String?>? _refreshing;
  bool _expired = false;
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.getAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  Future<String?> _refresh() async {
    try {
      final token = await secureStorage.getRefreshToken();
      if (token == null) return null;
      final result = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': token},
      );
      final access = result.data?['token']?.toString() ?? '';
      final refresh = result.data?['refreshToken']?.toString() ?? '';
      if (access.isEmpty || refresh.isEmpty) return null;
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
    if (err.response?.statusCode == 401 &&
        request.extra['authRetried'] == true) {
      await secureStorage.deleteTokens();
      handler.next(err);
      _notifyExpired();
      return;
    }
    if (err.response?.statusCode != 401 ||
        [
          ApiEndpoints.login,
          ApiEndpoints.register,
          ApiEndpoints.refreshToken,
        ].contains(request.path) ||
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
      if (token == null) {
        await secureStorage.deleteTokens();
        handler.next(err);
        _notifyExpired();
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

  void _notifyExpired() {
    if (!_expired) {
      _expired = true;
      scheduleMicrotask(() => onSessionExpired?.call());
    }
  }
}
