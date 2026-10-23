import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:web/web.dart' as web;

Future<String> recordingPath() async => 'voice-note.wav';

Future<Uint8List> readRecording(String path) => XFile(path).readAsBytes();

Future<void> deleteRecording(String path) async {
  if (path.startsWith('blob:')) web.URL.revokeObjectURL(path);
}
