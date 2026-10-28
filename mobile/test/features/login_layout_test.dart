import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/domain/repositories/auth_repository.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/auth/presentation/screens/login_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineAuth implements AuthRepository {
  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => throw DioException(
    requestOptions: RequestOptions(path: '/auth/login'),
    type: DioExceptionType.connectionTimeout,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final height in [450.0, 645.0, 730.0]) {
    testWidgets(
      'login scrolls validation and connection error at height $height',
      (tester) async {
        tester.view.physicalSize = Size(354, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_OfflineAuth()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const LoginScreen(),
            ),
          ),
        );
        final signIn = find.widgetWithText(FilledButton, 'Sign In');
        await tester.ensureVisible(signIn);
        await tester.tap(signIn);
        await tester.pumpAndSettle();
        expect(find.text('Enter your email address.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'member@example.test',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'test-password',
        );
        await tester.ensureVisible(signIn);
        await tester.tap(signIn);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'We could not connect right now. Please try again in a moment.',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Create an Account'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
