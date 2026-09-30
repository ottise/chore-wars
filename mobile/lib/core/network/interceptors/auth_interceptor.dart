import 'package:dio/dio.dart';

import '../../storage/secure_storage.dart';
import '../api_endpoints.dart';

/// Intercepts every request to attach the Bearer token.
/// On 401 (for non-auth endpoints) it attempts a token refresh.
/// If refresh fails, it clears tokens so the router redirect sends the user
/// back to /login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.secureStorage, required this.dio});

  final SecureStorage secureStorage;
  final Dio dio;
  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isAuthRoute =
        err.requestOptions.path == ApiEndpoints.login ||
        err.requestOptions.path == ApiEndpoints.register ||
        err.requestOptions.path == ApiEndpoints.refreshToken;

    if (err.response?.statusCode == 401 && !isAuthRoute && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await secureStorage.getRefreshToken();
        if (refreshToken == null) {
          await secureStorage.deleteTokens();
          return handler.next(err);
        }

        final refreshResponse = await dio.post<Map<String, dynamic>>(
          ApiEndpoints.refreshToken,
          data: {'refreshToken': refreshToken},
          options: Options(extra: {'skipAuthInterceptor': true}),
        );

        final newAccessToken =
            refreshResponse.data?['token']?.toString() ?? '';
        final newRefreshToken =
            refreshResponse.data?['refreshToken']?.toString() ?? '';

        await secureStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        // Retry the original request with the new token.
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await dio.fetch<dynamic>(opts);
        return handler.resolve(retryResponse);
      } catch (_) {
        await secureStorage.deleteTokens();
        return handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    }

    return handler.next(err);
  }
}
