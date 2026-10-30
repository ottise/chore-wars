import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/core/network/provider_retry.dart';
import 'package:chore_wars/features/auth/domain/repositories/auth_repository.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/auth/presentation/screens/register_screen.dart';
import 'package:chore_wars/features/auth/presentation/widgets/email_code_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Registration extends Fake implements AuthRepository {
  int calls = 0;
  final pending = Completer<void>();
  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    calls++;
    return pending.future;
  }
}

class _RejectedEmail implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancelled,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode({'detail': 'Account email is not available yet.'}),
      409,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('provider retries never repeat auth/client errors and cap transient failures at one', () {
    for (final status in [400, 401, 403, 404, 409, 429]) {
      final request = RequestOptions(path: '/test');
      expect(
        appProviderRetry(
          0,
          DioException(
            requestOptions: request,
            response: Response(requestOptions: request, statusCode: status),
          ),
        ),
        isNull,
      );
    }
    final error = DioException(
      requestOptions: RequestOptions(path: '/test'),
      type: DioExceptionType.connectionError,
    );
    expect(appProviderRetry(0, error), const Duration(seconds: 2));
    expect(appProviderRetry(1, error), isNull);
  });
  testWidgets(
    'registration submits once and waits after an unavailable email service',
    (tester) async {
      final repo = _Registration();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      final values = [
        'New user',
        'new@example.test',
        'Password1!',
        'Password1!',
      ];
      for (var i = 0; i < values.length; i++) {
        await tester.ensureVisible(find.byType(TextFormField).at(i));
        await tester.enterText(find.byType(TextFormField).at(i), values[i]);
      }
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(repo.calls, 1);
      repo.pending.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/auth/register'),
          type: DioExceptionType.connectionError,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try again in 30s.'), findsOneWidget);
      await tester.tap(find.text('Create account'));
      await tester.pump();
      expect(repo.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'OTP delivery failure also disables repeated sends for 60 seconds',
    (tester) async {
      final adapter = _RejectedEmail();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: const MaterialApp(
            home: Scaffold(
              body: EmailCodeDialog(
                email: 'new@example.test',
                resetPassword: false,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(adapter.calls, 1);
      expect(find.text('Account email is not available yet.'), findsOneWidget);
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(adapter.calls, 1);
      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(adapter.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
