import '../storage/session_provider.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import 'interceptors/auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  ref.watch(sessionEpochProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  final secureStorage = ref.watch(secureStorageProvider);
  dio.interceptors.add(
    AuthInterceptor(
      secureStorage: secureStorage,
      dio: dio,
      onSessionExpired: () {
        ref.read(sessionExpiryProvider.notifier).advance();
        ref.read(sessionEpochProvider.notifier).advance();
      },
    ),
  );

  ref.onDispose(() => dio.close(force: true));
  return dio;
});
