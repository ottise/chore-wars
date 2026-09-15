import 'package:dio/dio.dart';
import '../../storage/secure_storage.dart';
import '../api_endpoints.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorage secureStorage;
  final Dio dio;

  AuthInterceptor({required this.secureStorage, required this.dio});

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await secureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && err.requestOptions.path != ApiEndpoints.login) {
      // Logic for refresh token would go here
      // For now, if 401, we just forward the error
    }
    return handler.next(err);
  }
}
