import 'dart:convert';
import 'dart:typed_data';

import 'package:chore_wars/features/chat/presentation/widgets/audio_message_bubble.dart';
import 'package:chore_wars/features/chat/providers/voice_note_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(WidgetTester tester, Future<Uint8List> Function() load) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [privateMediaProvider.overrideWith((ref, id) => load())],
          child: const MaterialApp(
            home: Scaffold(body: PrivateImageBubble(attachmentId: 'old-photo')),
          ),
        ),
      );

  for (final status in [404, 410, 403]) {
    testWidgets(
      'photo HTTP $status shows a useful state instead of endless retries',
      (tester) async {
        await mount(tester, () async {
          final request = RequestOptions(path: '/media/old-photo');
          throw DioException(
            requestOptions: request,
            response: Response(requestOptions: request, statusCode: status),
            type: DioExceptionType.badResponse,
          );
        });
        await tester.pumpAndSettle();
        expect(find.text('Retry image'), findsNothing);
        expect(
          find.textContaining(
            status == 403
                ? 'no longer have access'
                : 'Photo unavailable on the server',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'temporary network failure can retry and display the recovered original',
    (tester) async {
      var attempts = 0;
      await mount(tester, () async {
        if (attempts++ == 0)
          throw DioException(
            requestOptions: RequestOptions(path: '/media/old-photo'),
            type: DioExceptionType.connectionError,
          );
        return base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWZkAAAAASUVORK5CYII=',
        );
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry image'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
