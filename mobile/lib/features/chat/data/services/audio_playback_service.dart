import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AudioPlaybackService extends ChangeNotifier with WidgetsBindingObserver {
  AudioPlaybackService() {
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _request++;
      unawaited(player.stop());
    }
  }

  final AudioPlayer player = AudioPlayer();
  String? activeId;
  final List<File> _files = [];
  bool _disposed = false;
  int _request = 0;
  Future<void> stop() async {
    _request++;
    if (!_disposed) await player.stop();
  }

  Future<void> playBytes(String id, List<int> bytes) async {
    final request = ++_request;
    await player.stop();
    if (_disposed || request != _request) return;
    final wav =
        bytes.length >= 12 &&
        bytes[0] == 82 &&
        bytes[1] == 73 &&
        bytes[2] == 70 &&
        bytes[3] == 70;
    if (kIsWeb) {
      activeId = id;
      await player.setUrl(
        Uri.dataFromBytes(
          bytes,
          mimeType: wav ? 'audio/wav' : 'audio/mp4',
        ).toString(),
      );
      if (_disposed || request != _request) return;
      notifyListeners();
      unawaited(player.play());
      return;
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/cw-audio-$id.${wav ? 'wav' : 'm4a'}');
    await file.writeAsBytes(bytes, flush: true);
    _files.add(file);
    if (_disposed || request != _request) {
      await file.delete();
      return;
    }
    activeId = id;
    await player.setFilePath(file.path);
    if (_disposed || request != _request) return;
    notifyListeners();
    unawaited(player.play());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _request++;
    unawaited(player.dispose());
    for (final file in _files) {
      unawaited(
        file.exists().then((exists) async {
          if (exists) await file.delete();
        }),
      );
    }
    super.dispose();
  }
}
