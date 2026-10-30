import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../providers/voice_note_provider.dart';
import '../../data/services/voice_file.dart';
import '../../../../core/utils/api_error_message.dart';

class VoiceNoteRecorder extends ConsumerStatefulWidget {
  const VoiceNoteRecorder({super.key, required this.onSend});
  final Future<void> Function(List<int>, String) onSend;
  @override
  ConsumerState<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends ConsumerState<VoiceNoteRecorder>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  Timer? _timer;
  String? _path;
  bool _recording = false, _busy = false, _stopping = false;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording) {
      unawaited(_stop());
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref.read(audioPlaybackProvider).stop();
      if (!await _recorder.hasPermission()) {
        throw StateError(
          'Microphone permission was denied. Enable it in phone settings to record.',
        );
      }
      final encoder = kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc;
      if (!await _recorder.isEncoderSupported(encoder)) {
        throw StateError(
          'Audio recording is unsupported. Check microphone permissions and try again.',
        );
      }
      final path = await recordingPath();
      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 59) unawaited(_stop());
      });
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop({bool send = false}) async {
    if (_stopping || !_recording) return;
    _stopping = true;
    _timer?.cancel();
    try {
      final path = await _recorder.stop();
      if (mounted) {
        setState(() {
          _path = path;
          _recording = false;
        });
        if (send && path != null) await _send();
      } else if (path != null) {
        await _deleteFile(path);
      }
    } catch (error) {
      _error(error);
    } finally {
      _stopping = false;
    }
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  static Future<void> _deleteFile(String path) async {
    await deleteRecording(path);
  }

  Future<void> _discard() async {
    await ref.read(audioPlaybackProvider).stop();
    final path = _path;
    if (path != null) await _deleteFile(path);
    if (mounted) setState(() => _path = null);
  }

  Future<void> _send() async {
    final path = _path;
    if (path == null || _busy) return;
    setState(() => _busy = true);
    try {
      final playback = ref.read(audioPlaybackProvider);
      final bytes = await readRecording(path);
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError('Voice note exceeds 5 MB.');
      }
      await playback.stop();
      await widget.onSend(bytes, kIsWeb ? 'voice-note.wav' : 'voice-note.m4a');
      if (mounted) setState(() => _path = null);
      // Delivery is confirmed; a cleanup failure must not offer Send again.
      try {
        await _deleteFile(path);
      } catch (_) {}
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_recorder.dispose());
    final path = _path;
    if (path != null) unawaited(_deleteFile(path));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_path == null)
        IconButton(
          tooltip: _recording ? 'Stop & send' : 'Record voice note',
          onPressed: _busy
              ? null
              : _recording
              ? () => _stop(send: true)
              : _start,
          icon: Icon(
            _recording ? Icons.stop_circle_outlined : Icons.mic_outlined,
          ),
        ),
      if (_recording) Text('${_seconds}s / 60s'),
      if (_recording)
        IconButton(
          tooltip: 'Cancel recording',
          onPressed: _stopping
              ? null
              : () async {
                  _timer?.cancel();
                  await _recorder.cancel();
                  if (mounted) setState(() => _recording = false);
                },
          icon: const Icon(Icons.close),
        ),
      if (_path != null) ...[
        IconButton(
          tooltip: 'Discard recording',
          onPressed: _busy ? null : _discard,
          icon: const Icon(Icons.delete_outline),
        ),
        IconButton(
          tooltip: 'Send saved voice note',
          onPressed: _busy ? null : _send,
          icon: _busy
              ? const CircularProgressIndicator()
              : const Icon(Icons.send_outlined),
        ),
      ],
    ],
  );
}
