import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/session_provider.dart';

final accountAvatarProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, avatarUrl) async {
      ref.watch(sessionEpochProvider);
      final response = await ref
          .watch(dioProvider)
          .get<List<int>>(
            '/user/avatar-image',
            options: Options(responseType: ResponseType.bytes),
          );
      return Uint8List.fromList(response.data!);
    });
