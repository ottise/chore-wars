import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/voice_note_provider.dart';

class AudioMessageBubble extends ConsumerWidget {
  final String attachmentId;
  const AudioMessageBubble({super.key, required this.attachmentId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioPlaybackProvider);
    return StreamBuilder(
      stream: audio.player.playerStateStream,
      builder: (context, _) {
        final playing = audio.activeId == attachmentId && audio.player.playing;
        return SizedBox(
          width: 240,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: playing ? 'Pause voice note' : 'Play voice note',
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () async {
                      try {
                        if (playing) {
                          await audio.player.pause();
                        } else {
                          final bytes = await ref.read(
                            privateMediaProvider(attachmentId).future,
                          );
                          await audio.playBytes(attachmentId, bytes);
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Cannot play this voice note. Check your connection and room access.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const Text('Voice note'),
                ],
              ),
              if (audio.activeId == attachmentId)
                StreamBuilder(
                  stream: audio.player.positionStream,
                  builder: (context, snapshot) => Text(
                    '${snapshot.data?.inSeconds ?? 0}s / ${audio.player.duration?.inSeconds ?? 0}s',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class PrivateImageBubble extends ConsumerWidget {
  final String attachmentId;
  const PrivateImageBubble({super.key, required this.attachmentId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(privateMediaProvider(attachmentId))
      .when(
        data: (bytes) =>
            Image.memory(bytes, width: 240, height: 240, fit: BoxFit.cover),
        loading: () => const SizedBox(
          width: 80,
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(privateMediaProvider(attachmentId)),
          child: const Text('Retry image'),
        ),
      );
}
