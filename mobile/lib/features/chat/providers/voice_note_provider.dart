import '../../../../core/storage/session_provider.dart';

import 'dart:async';

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../data/services/audio_playback_service.dart';

final privateMediaProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, id) async {
      ref.watch(sessionEpochProvider);
      final lease = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 5), lease.close);
      final cancel = CancelToken();
      ref.onDispose(() {
        timer.cancel();
        cancel.cancel();
      });
      final response = await ref
          .watch(dioProvider)
          .get<List<int>>(
            '/media/$id',
            options: Options(responseType: ResponseType.bytes),
            cancelToken: cancel,
          );
      return Uint8List.fromList(response.data!);
    }, retry: (_, _) => null);
final audioPlaybackProvider = Provider.autoDispose<AudioPlaybackService>((ref) {
  ref.watch(sessionEpochProvider);
  final service = AudioPlaybackService();
  ref.onDispose(service.dispose);
  return service;
});
