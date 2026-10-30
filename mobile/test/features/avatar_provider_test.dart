import 'dart:typed_data';

import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/core/storage/session_provider.dart';
import 'package:chore_wars/features/auth/presentation/providers/avatar_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Images implements HttpClientAdapter {
  int calls = 0;
  int status = 204;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromBytes(status == 200 ? [1, 2, 3] : [], status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final status in [204, 404]) {
    test(
      'missing avatar ($status) is cached as a fallback and reloaded after account switch',
      () async {
        final images = _Images()..status = status;
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
          ..httpClientAdapter = images;
        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(dio)],
        );
        addTearDown(container.dispose);
        addTearDown(dio.close);
        final provider = accountAvatarProvider('/avatars/old.png');
        expect(await container.read(provider.future), isNull);
        expect(await container.read(provider.future), isNull);
        expect(images.calls, 1);
        container.read(sessionEpochProvider.notifier).advance();
        expect(await container.read(provider.future), isNull);
        expect(images.calls, 2);
      },
    );
  }
  test('uploaded avatar bytes are available to every avatar widget', () async {
    final images = _Images()..status = 200;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
      ..httpClientAdapter = images;
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);
    addTearDown(dio.close);
    expect(
      await container.read(accountAvatarProvider('/avatars/new.png').future),
      [1, 2, 3],
    );
  });
}
