import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../providers/voice_note_provider.dart';

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
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/cw-record-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
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

  Future<void> _stop() async {
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
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  static Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> _discard() async {
    await ref.read(audioPlaybackProvider).stop();
    final path = _path;
    if (path != null) await _deleteFile(path);
    if (mounted) setState(() => _path = null);
  }

  Future<void> _send() async {
    final path = _path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final playback = ref.read(audioPlaybackProvider);
      final bytes = await File(path).readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError('Voice note exceeds 5 MB.');
      }
      await playback.stop();
      await widget.onSend(bytes, 'voice-note.m4a');
      await _deleteFile(path);
      if (mounted) setState(() => _path = null);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    final path = _path;
    if (path == null) return;
    final playback = ref.read(audioPlaybackProvider);
    try {
      final bytes = await File(path).readAsBytes();
      if (!mounted) return;
      await playback.playBytes('preview', bytes);
    } catch (error) {
      _error(error);
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
    children: [
      if (_path == null)
        IconButton(
          tooltip: _recording ? 'Stop recording' : 'Record voice note',
          onPressed: _busy
              ? null
              : _recording
              ? _stop
              : _start,
          icon: Icon(_recording ? Icons.stop_circle : Icons.mic),
        ),
      if (_recording) Text('${_seconds}s / 60s'),
      if (_path != null) ...[
        IconButton(
          tooltip: 'Preview recording',
          onPressed: _busy ? null : _preview,
          icon: const Icon(Icons.play_arrow),
        ),
        IconButton(
          tooltip: 'Discard recording',
          onPressed: _busy ? null : _discard,
          icon: const Icon(Icons.delete_outline),
        ),
        IconButton(
          tooltip: 'Send voice note',
          onPressed: _busy ? null : _send,
          icon: _busy
              ? const CircularProgressIndicator()
              : const Icon(Icons.send),
        ),
      ],
    ],
  );
}
