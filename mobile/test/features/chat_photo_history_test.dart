import 'dart:convert';
import 'dart:typed_data';

import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/chat/presentation/screens/chat_photo_history_screen.dart';
import 'package:chore_wars/features/chat/providers/voice_note_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Photos implements HttpClientAdapter {
  final pages = <int>[];
  bool empty = false;
  bool fail = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    expect(request.path, '/chat/rooms/room-A/photos');
    final page = request.queryParameters['page'] as int;
    pages.add(page);
    return ResponseBody.fromString(
      jsonEncode({
        'items': empty || fail
            ? []
            : [
                {
                  'id': 'photo-$page',
                  'roomId': 'room-A',
                  'senderId': 'sender',
                  'senderName': 'Member $page',
                  'messageType': 'IMAGE',
                  'attachmentId': 'attachment-$page',
                  'content': '',
                  'createdAt': '2026-10-25T10:00:00Z',
                },
              ],
        'totalCount': empty ? 0 : 25,
      }),
      fail ? 503 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<void> open(WidgetTester tester, _Photos server) async {
    final dio = Dio()..httpClientAdapter = server;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          privateMediaProvider.overrideWith(
            (ref, id) async => base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
          ),
        ],
        child: const MaterialApp(
          home: ChatPhotoHistoryScreen(roomId: 'room-A'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'photo history pages through server history and opens a full photo',
    (tester) async {
      final server = _Photos();
      await open(tester, server);
      expect(find.text('Member 1'), findsOneWidget);
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Member 2'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(server.pages, [1, 2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty photo history does not invent content', (tester) async {
    await open(tester, _Photos()..empty = true);
    expect(find.text('No photos shared in this chat yet.'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('history load failure can retry', (tester) async {
    final server = _Photos()..fail = true;
    await open(tester, server);
    server.fail = false;
    await tester.tap(find.text('Unable to load photos. Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Member 1'), findsOneWidget);
  });
}
