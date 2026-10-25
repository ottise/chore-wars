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

class AiEvidenceScreen extends ConsumerStatefulWidget {
  const AiEvidenceScreen({
    super.key,
    required this.occurrenceId,
    this.evidenceId,
  });
  final String occurrenceId;
  final String? evidenceId;
  @override
  ConsumerState<AiEvidenceScreen> createState() => _AiEvidenceScreenState();
}

class _AiEvidenceScreenState extends ConsumerState<AiEvidenceScreen> {
  Uint8List? bytes;
  String? id, request, error;
  Map? review;
  bool busy = false;
  int? epoch;
  @override
  void initState() {
    super.initState();
    id = widget.evidenceId;
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
      if (active(captured)) setState(() => error = apiErrorMessage(e));
    } finally {
      if (active(captured)) setState(() => busy = false);
    }
  }

  Future<void> upload(int captured) async {
    if (id != null) return;
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
        );
    if (active(captured)) {
      setState(() => id = (response.data as Map)['id'] as String);
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
    return Scaffold(
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
          if (widget.evidenceId == null)
            Wrap(
              spacing: 12,
              children: [
                for (final source in [ImageSource.camera, ImageSource.gallery])
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
                                      builder: (_) => const CapturePhotoScreen(
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
                            });
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
          if (widget.evidenceId != null && bytes == null)
            FilledButton.tonal(
              onPressed: busy
                  ? null
                  : () => run((captured) async {
                      final response = await ref
                          .read(dioProvider)
                          .get<List<int>>(
                            '/evidence/$id',
                            options: Options(responseType: ResponseType.bytes),
                          );
                      if (active(captured)) {
                        setState(
                          () => bytes = Uint8List.fromList(response.data!),
                        );
                      }
                    }),
              child: const Text('Open Attached Photo'),
            ),
          if (widget.evidenceId == null && bytes != null) ...[
            FilledButton.tonalIcon(
              onPressed: busy
                  ? null
                  : () => run((captured) async {
                      await upload(captured);
                      if (!active(captured)) return;
                      final response = await ref
                          .read(dioProvider)
                          .post(
                            '/occurrences/${widget.occurrenceId}/ai/verify-proof',
                            data: {'evidenceId': id},
                          );
                      if (active(captured)) {
                        setState(() => review = response.data as Map);
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
                              onPressed: () => Navigator.pop(context, false),
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
    );
  }
}
