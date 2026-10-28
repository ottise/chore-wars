import 'package:chore_wars/core/storage/secure_storage.dart';
import 'package:chore_wars/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:chore_wars/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chore_wars/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tokens extends SecureStorage {
  String access = 'existing-session', refresh = 'existing-refresh';
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }
}

void main() {
  test(
    'Google login exchanges only ID token and stores the Chore Wars session',
    () async {
      final tokens = _Tokens();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.path, '/auth/google');
            expect(request.data, {'idToken': 'google-identity-token'});
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'userId': 'member',
                  'displayName': 'Chi',
                  'token': 'app-jwt',
                  'refreshToken': 'app-refresh',
                },
              ),
            );
          },
        ),
      );
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(dio),
        secureStorage: tokens,
      );
      expect(
        (await repo.googleLogin('google-identity-token')).userId,
        'member',
      );
      expect(tokens.access, 'app-jwt');
      expect(tokens.refresh, 'app-refresh');
    },
  );

  test(
    'Google rejection and linking never overwrite the current session',
    () async {
      final tokens = _Tokens();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.path.endsWith('/link')) {
              handler.resolve(
                Response(requestOptions: request, statusCode: 200),
              );
            } else {
              handler.reject(
                DioException(
                  requestOptions: request,
                  response: Response(requestOptions: request, statusCode: 409),
                ),
              );
            }
          },
        ),
      );
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(dio),
        secureStorage: tokens,
      );
      await expectLater(
        repo.googleLogin('rejected-token'),
        throwsA(isA<DioException>()),
      );
      await repo.linkGoogle('link-token');
      expect(tokens.access, 'existing-session');
      expect(tokens.refresh, 'existing-refresh');
    },
  );

  testWidgets('unconfigured Google does not render a broken sign-in button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GoogleSignInButton(
          onToken: (_) async => fail('No SDK login expected'),
          onError: (_) => fail('No SDK error expected'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Continue with Google'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
