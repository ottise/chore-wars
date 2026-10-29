import '../storage/session_provider.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import 'interceptors/auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionEpochProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
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
      isSessionCurrent: () =>
          ref.mounted && ref.read(sessionEpochProvider) == session,
      onSessionExpired: () {
        ref.read(sessionExpiryProvider.notifier).advance();
        ref.read(sessionEpochProvider.notifier).advance();
      },
    ),
  );

  ref.onDispose(() => dio.close(force: true));
  return dio;
});
