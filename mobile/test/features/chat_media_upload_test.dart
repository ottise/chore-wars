import 'dart:convert';
import 'dart:typed_data';

import 'package:chore_wars/features/chat/data/services/chat_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MediaServer implements HttpClientAdapter {
  final uploads = <String>[];
  final sends = <Map<String, dynamic>>[];
  bool failFirstSend = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/media') {
      expect(options.contentType, startsWith('multipart/form-data; boundary='));
      final body = await requestStream!.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      uploads.add(latin1.decode(body));
      expect(uploads.last, contains('name="roomId"'));
      expect(uploads.last, contains('name="file"; filename="'));
      expect(uploads.last, isNot(contains('filename=""')));
      return response({'id': 'attachment'});
    }
    expect(options.path, '/media/send');
    sends.add(
      Map<String, dynamic>.from(
        jsonDecode(
          utf8.decode(
            await requestStream!.fold<List<int>>(
              [],
              (all, chunk) => all..addAll(chunk),
            ),
          ),
        ) as Map,
      ),
    );
    if (failFirstSend && sends.length == 1) {
      return response({'title': 'Temporary failure'}, status: 503);
    }
    return response({
      'id': 'message',
      'roomId': 'room',
      'senderId': 'user',
      'senderName': 'User',
      'content': '',
      'messageType': 'IMAGE',
      'attachmentId': 'attachment',
      'createdAt': '2026-10-24T00:00:00Z',
    });
  }

  ResponseBody response(Map<String, dynamic> body, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  void close({bool force = false}) {}
}

void main() {
  for (final filename in ['', '   ', 'gallery.jpg']) {
    test(
      'media upload supplies a multipart filename for "$filename"',
      () async {
        final server = _MediaServer();
        final dio = Dio(
          BaseOptions(
            headers: {Headers.contentTypeHeader: Headers.jsonContentType},
          ),
        )..httpClientAdapter = server;
        final result = await ChatApiService(dio)
            .sendMedia('room', [255, 216, 255, 1], filename, 'client');
        expect(result.messageType, 'IMAGE');
        expect(
          server.uploads.single,
          contains(
            'filename="${filename.trim().isEmpty ? 'attachment' : filename}"',
          ),
        );
        expect(server.sends.single, {
          'roomId': 'room',
          'attachmentId': 'attachment',
          'clientMessageId': 'client',
        });
      },
    );
  }

  test(
    'retrying an unnamed camera photo reuses the uploaded attachment',
    () async {
      final server = _MediaServer()..failFirstSend = true;
      final service = ChatApiService(Dio()..httpClientAdapter = server);
      await expectLater(
        service.sendMedia('room', [255, 216, 255, 1], '', 'client'),
        throwsA(isA<DioException>()),
      );
      await service.sendMedia('room', [255, 216, 255, 1], '', 'client');
      expect(server.uploads, hasLength(1));
      expect(server.sends, hasLength(2));
      expect(server.sends.first, server.sends.last);
    },
  );
}
