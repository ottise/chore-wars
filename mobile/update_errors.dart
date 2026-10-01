import 'dart:io';

void main() {
  final dir = Directory('lib/features');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = file.readAsStringSync();
    if (content.contains('error.toString()') && content.contains('showAppMessage')) {
      content = content.replaceAll('error.toString()', 'apiErrorMessage(error)');
      
      if (!content.contains('api_error_message.dart')) {
        final pathDepth = file.path.split(Platform.pathSeparator).length - 1;
        final prefix = List.filled(pathDepth - 1, '..').join('/');
        final importStatement = "import '$prefix/core/utils/api_error_message.dart';\n";
        
        // Find last import
        final lines = content.split('\n');
        var lastImportIdx = -1;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].startsWith('import ')) {
            lastImportIdx = i;
          }
        }
        
        if (lastImportIdx != -1) {
          lines.insert(lastImportIdx + 1, importStatement);
          content = lines.join('\n');
        }
      }
      
      file.writeAsStringSync(content);
      print('Updated \${file.path}');
    }
  }
}
