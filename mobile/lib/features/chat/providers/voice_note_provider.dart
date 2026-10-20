import '../../../../core/storage/session_provider.dart';

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../data/services/audio_playback_service.dart';

final privateMediaProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, id) async {
      final lease = ref.keepAlive();
      final cancel = CancelToken();
      ref.onDispose(() => cancel.cancel());
      try {
        final response = await ref
            .watch(dioProvider)
            .get<List<int>>(
              '/media/$id',
              options: Options(responseType: ResponseType.bytes),
              cancelToken: cancel,
            );
        return Uint8List.fromList(response.data!);
      } finally {
        lease.close();
      }
    });
final audioPlaybackProvider = Provider.autoDispose<AudioPlaybackService>((ref) {
  ref.watch(sessionEpochProvider);
  final service = AudioPlaybackService();
  ref.onDispose(service.dispose);
  return service;
});
