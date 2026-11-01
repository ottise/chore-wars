import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_provider.dart';

final evidencePhotoProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, id) async {
      ref.watch(sessionEpochProvider);
      final response = await ref
          .watch(dioProvider)
          .get<List<int>>(
            '/evidence/$id',
            options: Options(responseType: ResponseType.bytes),
          );
      return Uint8List.fromList(response.data!);
    }, retry: (_, _) => null);

class EvidencePhoto extends ConsumerWidget {
  const EvidencePhoto({required this.evidenceId, super.key});
  final String evidenceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(evidencePhotoProvider(evidenceId))
      .when(
        loading: () => const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) =>
            error is DioException &&
                (error.response?.statusCode == 404 ||
                    error.response?.statusCode == 410)
            ? const Text('Photo evidence is unavailable.')
            : TextButton.icon(
                onPressed: () =>
                    ref.invalidate(evidencePhotoProvider(evidenceId)),
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Retry saved photo'),
              ),
        data: (bytes) => Semantics(
          label: 'Saved chore photo. Tap to enlarge.',
          image: true,
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: InteractiveViewer(
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Text('Photo evidence is unavailable.'),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  bytes,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Photo evidence is unavailable.'),
                ),
              ),
            ),
          ),
        ),
      );
}
