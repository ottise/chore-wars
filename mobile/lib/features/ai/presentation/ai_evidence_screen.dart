import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_provider.dart';
import '../../../core/utils/api_error_message.dart';
import '../../chat/presentation/screens/capture_photo_screen.dart';
import 'evidence_photo.dart';

class AiEvidenceScreen extends ConsumerStatefulWidget {
  const AiEvidenceScreen({
    super.key,
    required this.occurrenceId,
    this.evidenceId,
    this.canEdit = true,
    this.canComplete = true,
  });
  final String occurrenceId;
  final String? evidenceId;
  final bool canEdit;
  final bool canComplete;
  @override
  ConsumerState<AiEvidenceScreen> createState() => _AiEvidenceScreenState();
}

class _AiEvidenceScreenState extends ConsumerState<AiEvidenceScreen> {
  Uint8List? bytes;
  String? id, request, error;
  Map? review;
  bool busy = false;
  bool saved = false;
  int? epoch;
  @override
  void initState() {
    super.initState();
    id = widget.evidenceId;
    saved = id != null;
  }

  bool active(int captured) =>
      mounted && ref.read(sessionEpochProvider) == captured;
  Future<void> run(Future<void> Function(int) operation) async {
    if (busy) return;
    final captured = ref.read(sessionEpochProvider);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation(captured);
    } catch (e) {
      if (active(captured)) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : apiErrorMessage(e),
        );
      }
    } finally {
      if (active(captured)) setState(() => busy = false);
    }
  }

  Future<void> upload(int captured) async {
    if (id != null) {
      if (!saved) await save(captured);
      return;
    }
    if (bytes == null) throw StateError('Choose a photo before uploading.');
    request ??= const Uuid().v4();
    final response = await ref
        .read(dioProvider)
        .post(
          '/occurrences/${widget.occurrenceId}/evidence',
          data: FormData.fromMap({
            'clientRequestId': request,
            'file': MultipartFile.fromBytes(bytes!, filename: 'evidence.jpg'),
          }),
          options: Options(contentType: 'multipart/form-data'),
        );
    if (active(captured)) {
      setState(() => id = (response.data as Map)['id'] as String);
      await save(captured);
    }
  }

  Future<void> save(int captured) async {
    await ref
        .read(dioProvider)
        .post('/occurrences/${widget.occurrenceId}/evidence/$id/attach');
    if (active(captured)) {
      ref.invalidate(evidencePhotoProvider(id!));
      setState(() => saved = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(sessionEpochProvider);
    epoch ??= current;
    if (epoch != current) {
      return const Scaffold(
        body: Center(child: Text('Your session changed. Reopen the chore.')),
      );
    }
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Photo Evidence')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Photos are private to your household. AI feedback is advisory; you decide when the chore is complete.',
            ),
            if (bytes != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Image.memory(bytes!, height: 260, fit: BoxFit.contain),
              ),
            if (id != null && bytes == null) EvidencePhoto(evidenceId: id!),
            if (saved) const Text('Photo saved to this chore.'),
            if (widget.canEdit)
              Wrap(
                spacing: 12,
                children: [
                  for (final source in [
                    ImageSource.camera,
                    ImageSource.gallery,
                  ])
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => run((captured) async {
                              final picked = source == ImageSource.camera
                                  ? await Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).push<XFile>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CapturePhotoScreen(
                                              title: 'Capture Photo Evidence',
                                              captureLabel: 'Use This Photo',
                                            ),
                                      ),
                                    )
                                  : await ImagePicker().pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 1600,
                                      imageQuality: 80,
                                    );
                              if (picked == null || !active(captured)) return;
                              final selected = await picked.readAsBytes();
                              if (!active(captured)) return;
                              if (selected.length > 5000000) {
                                throw StateError('Photo exceeds 5 MB.');
                              }
                              setState(() {
                                bytes = selected;
                                id = null;
                                request = null;
                                review = null;
                                saved = false;
                              });
                              await upload(captured);
                            }),
                      icon: Icon(
                        source == ImageSource.camera
                            ? Icons.camera_alt_outlined
                            : Icons.photo_library_outlined,
                      ),
                      label: Text(
                        source == ImageSource.camera
                            ? 'Take Photo'
                            : 'Choose Photo',
                      ),
                    ),
                ],
              ),
            if (widget.canEdit && (bytes != null || id != null)) ...[
              if (!saved)
                FilledButton.icon(
                  onPressed: busy ? null : () => run(upload),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save photo'),
                ),
              FilledButton.tonalIcon(
                onPressed: busy
                    ? null
                    : () => run((captured) async {
                        await upload(captured);
                        if (!active(captured)) return;
                        try {
                          final response = await ref
                              .read(dioProvider)
                              .post(
                                '/occurrences/${widget.occurrenceId}/ai/verify-proof',
                                data: {'evidenceId': id},
                              );
                          if (active(captured)) {
                            setState(() => review = response.data as Map);
                          }
                        } catch (_) {
                          if (active(captured)) {
                            setState(
                              () => error = 'Photo saved. AI feedback is unavailable. You can still complete the chore.',
                            );
                          }
                        }
                      }),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Request AI Feedback (Optional)'),
              ),
              if (review != null) ...[
                Text('Result: ${review!['result']}'),
                for (final line in [
                  ...(review!['observations'] as List? ?? []),
                  ...(review!['limitations'] as List? ?? []),
                ])
                  Text('• $line'),
              ],
              if (widget.canComplete)
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => run((captured) async {
                          await upload(captured);
                          if (!active(captured) || !context.mounted) return;
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Completion?'),
                              content: const Text(
                                'AI feedback does not determine points. Current season and chore rules still apply.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Completed'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !active(captured)) return;
                          await ref
                              .read(dioProvider)
                              .post(
                                '/occurrences/${widget.occurrenceId}/complete',
                                data: {'evidenceId': id},
                              );
                          if (active(captured) && context.mounted) {
                            Navigator.pop(context, true);
                          }
                        }),
                  icon: const Icon(Icons.check_outlined),
                  label: const Text('Complete with This Photo'),
                ),
            ],
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
