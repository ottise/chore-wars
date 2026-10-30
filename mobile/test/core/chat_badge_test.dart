import 'package:chore_wars/core/utils/vietnam_time.dart';
import 'package:chore_wars/core/widgets/app_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Vietnam display time changes the day without modifying the UTC instant',
    () {
      final instant = DateTime.parse('2026-11-26T18:30:00Z');
      final display = vietnamTime(instant);
      expect(display.day, 27);
      expect(display.hour, 1);
      expect(display.minute, 30);
      expect(instant.hour, 18);
    },
  );
  for (final count in [0, 1, 10, 11]) {
    testWidgets('Chat navigation unread $count shows the bounded count', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomBar(
              paths: const ['/', '/chores', '/chat', '/orders', '/bounties'],
              selected: 0,
              chatUnread: count,
            ),
          ),
        ),
      );
      final badge = tester.widget<Badge>(find.byType(Badge).at(2));
      expect(badge.isLabelVisible, count > 0);
      if (count > 0) {
        expect(find.text(count > 10 ? '10+' : '$count'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
