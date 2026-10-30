import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/session_provider.dart';

final memberAvatarProvider = FutureProvider.autoDispose
    .family<Uint8List?, ({String house, String user, String version})>((
      ref,
      key,
    ) async {
      ref.watch(sessionEpochProvider);
      final cache = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 5), cache.close);
      ref.onDispose(timer.cancel);
      final response = await ref
          .watch(dioProvider)
          .get<List<int>>(
            '/houses/${key.house}/members/${key.user}/avatar',
            options: Options(
              responseType: ResponseType.bytes,
              validateStatus: (s) => s == 200 || s == 204 || s == 404,
            ),
          );
      return response.statusCode == 200 && response.data?.isNotEmpty == true
          ? Uint8List.fromList(response.data!)
          : null;
    }, retry: (_, _) => null);

class MemberAvatar extends ConsumerWidget {
  const MemberAvatar({
    required this.houseId,
    required this.userId,
    required this.name,
    this.version = '',
    super.key,
  });
  final String houseId, userId, name, version;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref
        .watch(
          memberAvatarProvider((
            house: houseId,
            user: userId,
            version: version,
          )),
        )
        .asData
        ?.value;
    return CircleAvatar(
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes == null
          ? Text(name.isEmpty ? '?' : name.characters.first.toUpperCase())
          : null,
    );
  }
}
