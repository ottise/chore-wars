import 'dart:io';

void main() {
  final dir = Directory('lib/features');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = file.readAsStringSync();
    var changed = false;
    
    if (content.contains("import '../../../core/utils/api_error_message.dart';")) {
      content = content.replaceAll("import '../../../core/utils/api_error_message.dart';", "import '../../../../core/utils/api_error_message.dart';");
      changed = true;
    }
    
    if (content.contains("import '../../core/utils/api_error_message.dart';")) {
      content = content.replaceAll("import '../../core/utils/api_error_message.dart';", "import '../../../../core/utils/api_error_message.dart';");
      changed = true;
    }

    if (changed) {
      file.writeAsStringSync(content);
      print('Fixed \${file.path}');
    }
  }
}
