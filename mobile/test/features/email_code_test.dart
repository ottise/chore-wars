import 'dart:convert';
import 'dart:typed_data';

import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/auth/presentation/widgets/email_code_dialog.dart';
import 'package:chore_wars/features/supplies/presentation/widgets/supplies_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  bool reject = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(request);
    return ResponseBody.fromString(
      jsonEncode({'detail': 'The code is invalid or expired.'}),
      reject ? 403 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final reset in [false, true]) {
    testWidgets(
      'OTP ${reset ? 'password reset' : 'email verification'} posts the correct purpose and keeps a rejected code editable',
      (tester) async {
        final adapter = _Api();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
          ..httpClientAdapter = adapter;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [dioProvider.overrideWithValue(dio)],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showEmailCodeDialog(
                      context,
                      email: 'test@example.test',
                      resetPassword: reset,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Send code'));
        await tester.pumpAndSettle();
        expect(
          adapter.calls.single.data['purpose'],
          reset ? 'RESET_PASSWORD' : 'VERIFY_EMAIL',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Verification code'),
          '123456',
        );
        if (reset) {
          await tester.enterText(
            find.widgetWithText(TextField, 'New password'),
            'NewPassword1!',
          );
        }
        adapter.reject = true;
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(find.text('The code is invalid or expired.'), findsOneWidget);
        expect(find.text('123456'), findsOneWidget);
        expect(
          adapter.calls.last.path,
          reset ? '/auth/password/reset' : '/auth/email-otp/verify',
        );
        expect(adapter.calls.last.data['code'], '123456');
        if (reset) {
          expect(adapter.calls.last.data['newPassword'], 'NewPassword1!');
        }
        await tester.tap(find.text('Resend code'));
        await tester.pumpAndSettle();
        expect(adapter.calls, hasLength(2));
        expect(
          find.textContaining('Wait one minute before requesting another code.'),
          findsOneWidget,
        );
        dio.close();
      },
    );
  }
  test('SMS body uses the persisted item quantity and total', () {
    final text = supplySmsBody({
      'id': 'saved-order',
      'total': 300000,
      'lines': [
        {'quantity': 2, 'name': 'ST25 rice', 'unit': '5 kg bag'},
      ],
    });
    expect(text, contains('2 x ST25 rice (5 kg bag)'));
    expect(text, contains('300,000 VND'));
  });
}
