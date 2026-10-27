import 'package:chore_wars/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared web accepts HTTPS hosts and loopback development only', () {
    for (final url in [
      'https://shared.example.test',
      'http://localhost:3001',
      'http://127.0.0.1:3001',
      'http://[::1]:3001',
    ]) {
      expect(
        () => AppConstants.validateWebOrigin(Uri.parse(url)),
        returnsNormally,
      );
    }
    for (final url in [
      'http://shared.example.test',
      'http://192.168.1.2:3001',
      'file:///index.html',
      'ftp://shared.example.test',
    ]) {
      expect(
        () => AppConstants.validateWebOrigin(Uri.parse(url)),
        throwsStateError,
      );
    }
  });
}
