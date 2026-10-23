import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/chat/presentation/widgets/audio_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'voice message is visible before loading private audio on a narrow screen',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  child: AudioMessageBubble(attachmentId: 'voice'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Voice message'), findsOneWidget);
      expect(find.text('Tap to listen'), findsOneWidget);
      expect(find.byTooltip('Play voice note'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
