import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> recordingPath() async {
  final directory = await getTemporaryDirectory();
  return '${directory.path}/cw-record-${DateTime.now().microsecondsSinceEpoch}.m4a';
}

Future<Uint8List> readRecording(String path) => File(path).readAsBytes();

Future<void> deleteRecording(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
