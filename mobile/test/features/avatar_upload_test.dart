import 'dart:convert';
import 'dart:typed_data';

import 'package:chore_wars/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Server implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    expect(request.uri.path, '/api/user/avatar');
    expect(request.contentType, startsWith('multipart/form-data; boundary='));
    final bytes = await stream!.fold<List<int>>(
      [],
      (all, chunk) => all..addAll(chunk),
    );
    expect(
      latin1.decode(bytes),
      contains('name="file"; filename="avatar.png"'),
    );
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'me',
        'email': 'me@example.test',
        'displayName': 'Me',
        'avatarUrl': '/avatars/saved.png',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('avatar uploads bytes without a local filesystem path or duplicate api prefix', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:5297/api',
        headers: {Headers.contentTypeHeader: 'application/json'},
      ),
    )..httpClientAdapter = _Server();
    final profile = await AuthRemoteDataSource(dio)
        .uploadAvatar([137, 80, 78, 71], 'avatar.png');
    expect(profile.avatarUrl, '/avatars/saved.png');
  });
}
