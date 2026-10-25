import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/auth/presentation/screens/profile_screen.dart';
import 'package:chore_wars/features/gamification/domain/entities/gamification_models.dart';
import 'package:chore_wars/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/notifications/domain/entities/notification_models.dart';
import 'package:chore_wars/features/notifications/presentation/providers/notification_providers.dart';
import 'package:chore_wars/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Inbox extends NotificationNotifier {
  final read = <String>[];
  @override
  NotificationState build() => NotificationState(
    notifications: [
      for (final row in [
        ('chat-A', 'CHAT_MENTION', 'house-A'),
        ('chat-B', 'CHAT_MESSAGE', 'house-B'),
        ('system-A', 'CHORE_ASSIGNED', 'house-A'),
        ('system-bounty', 'BOUNTY_CREATED', 'house-B'),
        ('system-alert', 'PAYMENT_DUE', 'house-A'),
      ])
        AppNotification.fromJson({
          'id': row.$1,
          'userId': 'user',
          'title': row.$1,
          'message': 'Message',
          'type': row.$2,
          'houseId': row.$3,
          'createdAt': '2026-10-23T00:00:00Z',
        }),
    ],
  );
  @override
  Future<void> markAsRead(String id) async {
    read.add(id);
    state = NotificationState(
      notifications: state.notifications
          .map((n) => n.id == id ? n.asRead() : n)
          .toList(),
    );
  }
}

void main() {
  testWidgets('system filters and mark-read affect only visible category', (
    tester,
  ) async {
    final inbox = _Inbox();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationNotifierProvider.overrideWith(() => inbox)],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('All 5'), findsOneWidget);
    expect(find.text('chat-A'), findsOneWidget);
    await tester.tap(find.text('Bounty'));
    await tester.pumpAndSettle();
    expect(find.text('system-bounty'), findsOneWidget);
    expect(find.text('system-A'), findsNothing);
    await tester.tap(find.text('Mark All Read'));
    await tester.pumpAndSettle();
    expect(inbox.read, ['system-bounty']);
    await tester.tap(find.text('Chores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark All Read'));
    await tester.pumpAndSettle();
    expect(inbox.read, ['system-bounty', 'system-A']);
  });
  testWidgets(
    'profile places Karma in personal tab and schedule in its own tab',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) async => const UserProfile(
                id: 'me',
                email: 'me@example.test',
                displayName: 'An',
              ),
            ),
            karmaSummaryProvider.overrideWith((ref, id) async {
              expect(id, 'house-A');
              return const KarmaSummary(
                current: 42,
                normalChores: 30,
                bonus: 12,
                penalties: 0,
              );
            }),
            activeSeasonProvider.overrideWith((ref, id) async => null),
            houseDetailProvider.overrideWith(
              (ref, id) async => House(
                id: id,
                name: 'Nhà A',
                inviteCode: 'TESTCODE',
                createdAt: DateTime.utc(2026),
              ),
            ),
          ],
          child: const MaterialApp(home: ProfileScreen(houseId: 'house-A')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personal Profile'), findsOneWidget);
      expect(find.text('Schedule & Routine'), findsOneWidget);
      expect(find.text('My Karma Score'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      await tester.tap(find.text('Schedule & Routine'));
      await tester.pumpAndSettle();
      expect(
        find.text('No season is available to configure your schedule.'),
        findsOneWidget,
      );
      expect(find.text('My Karma Score'), findsNothing);
    },
  );
  testWidgets(
    'chat inbox and mark-read stay within the selected house and category',
    (tester) async {
      final inbox = _Inbox();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [notificationNotifierProvider.overrideWith(() => inbox)],
          child: const MaterialApp(
            home: NotificationsScreen(houseId: 'house-A', chatOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('chat-A'), findsOneWidget);
      expect(find.text('chat-B'), findsNothing);
      expect(find.text('system-A'), findsNothing);
      await tester.tap(find.text('Mark All Read'));
      await tester.pumpAndSettle();
      expect(inbox.read, ['chat-A']);
    },
  );
}
