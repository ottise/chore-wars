import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/core/widgets/app_page_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brand and secondary text retain readable contrast', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    final colors = AppTheme.lightTheme.colorScheme;
    expect(
      contrast(colors.primary, colors.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(colors.onSurfaceVariant, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets(
    'page layout inherits the app theme without a second visual system',
    (tester) async {
      final theme = AppTheme.lightTheme;
      ThemeData? inherited;
      ThemeData? outside;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              outside = Theme.of(context);
              return AppPageFrame(
                builder: (context) {
                  inherited = Theme.of(context);
                  return const Scaffold(body: Text('Việc nhà & thông báo'));
                },
              );
            },
          ),
        ),
      );
      expect(inherited!.colorScheme, theme.colorScheme);
      expect(inherited!.textTheme, outside!.textTheme);
      expect(inherited!.cardTheme, outside!.cardTheme);
      expect(tester.takeException(), isNull);
    },
  );
}
