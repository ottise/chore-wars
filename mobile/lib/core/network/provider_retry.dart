import 'package:dio/dio.dart';

// Reads may retry once on a transport/server outage. Auth, validation and
// rate-limit failures need a user action, never a background retry loop.
Duration? appProviderRetry(int retryCount, Object error) {
  if (retryCount >= 1 || error is! DioException) return null;
  final status = error.response?.statusCode;
  if (status != null && status < 500) return null;
  if (error.type == DioExceptionType.cancel ||
      error.type == DioExceptionType.badCertificate) {
    return null;
  }
  return const Duration(seconds: 2);
}
