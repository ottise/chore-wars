import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chore_wars/core/network/api_endpoints.dart';
import 'package:chore_wars/core/network/interceptors/auth_interceptor.dart';
import 'package:chore_wars/core/storage/secure_storage.dart';

class MemoryTokens extends SecureStorage {
  String? access = 'old';
  String? refresh = 'refresh';
  @override
  Future<String?> getAccessToken() async => access;
  @override
  Future<String?> getRefreshToken() async => refresh;
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> deleteTokens() async {
    access = null;
    refresh = null;
  }
}

class RefreshAdapter implements HttpClientAdapter {
  int refreshes = 0;
  bool denyRetry = false;
  bool denyRefresh = false;
  Completer<void>? refreshStarted;
  Completer<void>? releaseRefresh;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == ApiEndpoints.refreshToken) {
      refreshes++;
      refreshStarted?.complete();
      if (releaseRefresh != null) await releaseRefresh!.future;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (denyRefresh) return ResponseBody.fromString('{}', 403);
      return ResponseBody.fromString(
        '{"token":"new","refreshToken":"next"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{}',
      options.headers['Authorization'] == 'Bearer new' && !denyRetry
          ? 200
          : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'requests after session expiry never hit auth or protected endpoints again',
    () async {
      final adapter = RefreshAdapter()..denyRefresh = true;
      final tokens = MemoryTokens();
      var expired = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(
          secureStorage: tokens,
          dio: dio,
          onSessionExpired: () => expired++,
        ),
      );
      await expectLater(dio.get('/first'), throwsA(isA<DioException>()));
      final calls = adapter.requests.length;
      for (var i = 0; i < 10; i++) {
        await expectLater(dio.get('/profile'), throwsA(isA<DioException>()));
      }
      await Future<void>.delayed(Duration.zero);
      expect(adapter.requests.length, calls);
      expect(adapter.refreshes, 1);
      expect(expired, 1);
      dio.close();
    },
  );
  for (final deny in [false, true]) {
    test(
      'old refresh (denied=$deny) cannot replace a new Google session',
      () async {
        final adapter = RefreshAdapter()
          ..denyRefresh = deny
          ..refreshStarted = Completer<void>()
          ..releaseRefresh = Completer<void>();
        final tokens = MemoryTokens();
        var current = true;
        var expired = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter;
        dio.interceptors.add(
          AuthInterceptor(
            secureStorage: tokens,
            dio: dio,
            isSessionCurrent: () => current,
            onSessionExpired: () => expired++,
          ),
        );
        final pending = expectLater(
          dio.get('/profile'),
          throwsA(isA<DioException>()),
        );
        await adapter.refreshStarted!.future;
        await tokens.saveTokens(
          accessToken: 'google-session',
          refreshToken: 'google-refresh',
        );
        current = false;
        adapter.releaseRefresh!.complete();
        await pending;
        await Future<void>.delayed(Duration.zero);
        expect(tokens.access, 'google-session');
        expect(tokens.refresh, 'google-refresh');
        expect(expired, 0);
        expect(
          adapter.requests.where((r) => r.path == '/profile'),
          hasLength(1),
        );
        dio.close();
      },
    );
  }
  test('public Google exchange sends no stale bearer and never refreshes on rejection', () async {
    final adapter = RefreshAdapter();
    final tokens = MemoryTokens();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(secureStorage: tokens, dio: dio));
    await expectLater(
      dio.post(
        ApiEndpoints.googleLogin,
        data: {'idToken': 'rejected-test-token'},
        options: Options(headers: {'Authorization': 'Bearer stale'}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
    expect(adapter.refreshes, 0);
    expect(tokens.access, 'old');
    dio.close();
  });
  test('refresh denied during multipart clears the session without replaying upload', () async {
    final adapter = RefreshAdapter()..denyRefresh = true;
    final tokens = MemoryTokens();
    var expired = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        secureStorage: tokens,
        dio: dio,
        onSessionExpired: () => expired++,
      ),
    );
    await expectLater(
      dio.post(
        '/media',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes([1, 2, 3], filename: 'proof.png'),
        }),
      ),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(tokens.access, isNull);
    expect(adapter.refreshes, 1);
    expect(expired, 1);
    dio.close();
  });
  test(
    'multipart is not replayed after refresh; explicit retry uses a new body',
    () async {
      final adapter = RefreshAdapter(), tokens = MemoryTokens();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(AuthInterceptor(secureStorage: tokens, dio: dio));
      FormData body() => FormData.fromMap({
        'file': MultipartFile.fromBytes([1, 2, 3], filename: 'voice.m4a'),
      });
      await expectLater(
        dio.post('/media', data: body()),
        throwsA(isA<DioException>()),
      );
      expect(adapter.refreshes, 1);
      expect(tokens.access, 'new');
      final response = await dio.post('/media', data: body());
      expect(response.statusCode, 200);
      expect(adapter.refreshes, 1);
      dio.close();
    },
  );
  test(
    'failed concurrent refresh clears tokens and expires the session once',
    () async {
      final adapter = RefreshAdapter()..denyRefresh = true;
      final tokens = MemoryTokens();
      var expired = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(
          secureStorage: tokens,
          dio: dio,
          onSessionExpired: () => expired++,
        ),
      );
      await Future.wait(
        ['/one', '/two', '/three'].map((path) async {
          await expectLater(dio.get(path), throwsA(isA<DioException>()));
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(adapter.refreshes, 1);
      expect(tokens.access, isNull);
      expect(expired, 1);
      dio.close();
    },
  );
  test('concurrent 401s share one token refresh', () async {
    final adapter = RefreshAdapter(), tokens = MemoryTokens();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(secureStorage: tokens, dio: dio));
    final responses = await Future.wait([
      dio.get('/one'),
      dio.get('/two'),
      dio.get('/three'),
    ]);
    expect(adapter.refreshes, 1);
    expect(responses.every((r) => r.statusCode == 200), isTrue);
    dio.close();
  });
  test(
    'an unauthorized retry never creates an infinite refresh loop',
    () async {
      final adapter = RefreshAdapter()..denyRetry = true;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(secureStorage: MemoryTokens(), dio: dio),
      );
      await expectLater(dio.get('/one'), throwsA(isA<DioException>()));
      expect(adapter.refreshes, 1);
      dio.close();
    },
  );
}
