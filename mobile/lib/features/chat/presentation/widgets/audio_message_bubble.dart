import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../providers/voice_note_provider.dart';

class AudioMessageBubble extends ConsumerStatefulWidget {
  const AudioMessageBubble({
    super.key,
    required this.attachmentId,
    this.isMe = false,
  });
  final String attachmentId;
  final bool isMe;
  @override
  ConsumerState<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends ConsumerState<AudioMessageBubble> {
  bool _loading = false;
  Duration? _duration;
  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _toggle(bool playing) async {
    final audio = ref.read(audioPlaybackProvider);
    try {
      if (playing) {
        await audio.player.pause();
      } else if (audio.activeId == widget.attachmentId &&
          audio.player.processingState != ProcessingState.idle) {
        if (audio.player.processingState == ProcessingState.completed) {
          await audio.player.seek(Duration.zero);
        }
        await audio.player.play();
      } else {
        setState(() => _loading = true);
        final bytes = await ref.read(
          privateMediaProvider(widget.attachmentId).future,
        );
        if (!mounted) return;
        await audio.playBytes(widget.attachmentId, bytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot play this voice note. Check your connection and room access.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioPlaybackProvider);
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) => StreamBuilder<PlayerState>(
        stream: audio.player.playerStateStream,
        builder: (context, _) {
          final active = audio.activeId == widget.attachmentId;
          final completed =
              active &&
              audio.player.processingState == ProcessingState.completed;
          final playing = active && audio.player.playing && !completed;
          return StreamBuilder<Duration?>(
            stream: audio.player.durationStream,
            builder: (context, _) {
              if (active && audio.player.duration != null) {
                _duration = audio.player.duration;
              }
              return StreamBuilder<Duration>(
                stream: audio.player.positionStream,
                builder: (context, snapshot) {
                  final position = active
                      ? (snapshot.data ?? audio.player.position)
                      : Duration.zero;
                  final total = _duration?.inMilliseconds ?? 0;
                  final progress = total > 0
                      ? (position.inMilliseconds / total).clamp(0.0, 1.0)
                      : 0.0;
                  return Container(
                    width: 260,
                    padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? colors.primaryFixed
                          : colors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: .12),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton.filled(
                          tooltip: playing
                              ? 'Pause voice note'
                              : completed
                              ? 'Replay voice note'
                              : 'Play voice note',
                          style: IconButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            disabledBackgroundColor: colors.primaryFixedDim,
                          ),
                          onPressed: _loading ? null : () => _toggle(playing),
                          icon: _loading
                              ? SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.primary,
                                  ),
                                )
                              : Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 27,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.mic_outlined,
                                    size: 14,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Voice message',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Semantics(
                                label: 'Voice message progress',
                                value: '${(progress * 100).round()} percent',
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 5,
                                  borderRadius: BorderRadius.circular(8),
                                  color: colors.primary,
                                  backgroundColor: colors.primary.withValues(
                                    alpha: .12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _loading
                                    ? 'Loading audio…'
                                    : _duration == null
                                    ? 'Tap to listen'
                                    : '${_time(position)} / ${_time(_duration!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
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
        data: (bytes) => Semantics(
          label: 'Chat photo. Tap to enlarge.',
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
                        child: Image.memory(bytes, fit: BoxFit.contain),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                width: 240,
                height: 240,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
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
