import 'dart:typed_data';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/session_provider.dart';

final accountAvatarProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, avatarUrl) async {
      ref.watch(sessionEpochProvider);
      final cache = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 5), cache.close);
      ref.onDispose(timer.cancel);
      final response = await ref
          .watch(dioProvider)
          .get<List<int>>(
            '/user/avatar-image',
            options: Options(
              responseType: ResponseType.bytes,
              validateStatus: (status) =>
                  status == 200 || status == 204 || status == 404,
            ),
          );
      // Cache absence as a successful fallback instead of retrying a missing image.
      if (response.statusCode != 200 || response.data?.isNotEmpty != true) {
        return null;
      }
      return Uint8List.fromList(response.data!);
    });
