import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/auth/presentation/screens/profile_screen.dart';
import 'package:chore_wars/features/gamification/domain/entities/gamification_models.dart';
import 'package:chore_wars/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/house/presentation/providers/current_house_provider.dart';
import 'package:chore_wars/features/house/presentation/screens/my_houses_screen.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/notifications/domain/entities/notification_models.dart';
import 'package:chore_wars/features/notifications/presentation/providers/notification_providers.dart';
import 'package:chore_wars/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  testWidgets(
    'profile from My Houses ignores the previously selected house and only loads account data',
    (tester) async {
      final householdReads = <String>[];
      const user = UserProfile(
        id: 'me',
        email: 'me@example.test',
        displayName: 'Chi',
      );
      final house = House(
        id: 'house-A',
        name: 'Private household',
        inviteCode: 'TESTCODE',
        createdAt: DateTime.utc(2026),
      );
      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith((ref) async => user),
          myHousesProvider.overrideWith((ref) async => [house]),
          houseDetailProvider.overrideWith((ref, id) async {
            householdReads.add('house:$id');
            return house;
          }),
          karmaSummaryProvider.overrideWith((ref, id) async {
            householdReads.add('karma:$id');
            return const KarmaSummary(
              current: 42,
              normalChores: 30,
              bonus: 12,
              penalties: 0,
            );
          }),
          activeSeasonProvider.overrideWith((ref, id) async {
            householdReads.add('season:$id');
            return null;
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(currentHouseProvider.notifier).setHouse(house.id);
      final router = GoRouter(
        initialLocation: '/houses',
        routes: [
          GoRoute(path: '/houses', builder: (_, _) => const MyHousesScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: '/profile/edit',
            builder: (_, state) {
              expect(state.extra, same(user));
              return const Scaffold(body: Text('Edit account'));
            },
          ),
          GoRoute(
            path: '/houses/:houseId/account',
            builder: (_, state) =>
                ProfileScreen(houseId: state.pathParameters['houseId']!),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Chi'), findsOneWidget);
      expect(find.text('me@example.test'), findsOneWidget);
      expect(find.text('Edit Profile Information'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
      for (final text in [
        'Private household',
        'Owner',
        'Member',
        'Profile',
        'Chore Settings',
        'My Karma Score',
        'My Notifications',
        'Household Chores',
      ]) {
        expect(find.text(text), findsNothing);
      }
      expect(find.byType(TabBar), findsNothing);
      expect(householdReads, isEmpty);
      expect(container.read(currentHouseProvider), house.id);
      await tester.tap(find.text('Edit Profile Information'));
      await tester.pumpAndSettle();
      expect(find.text('Edit account'), findsOneWidget);
      router.go('/houses/${house.id}/account');
      await tester.pumpAndSettle();
      expect(find.text('Chore Settings'), findsOneWidget);
      expect(find.text('My Karma Score'), findsOneWidget);
      expect(householdReads, containsAll(['house:house-A', 'karma:house-A']));
      expect(tester.takeException(), isNull);
    },
  );

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
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Chore Settings'), findsOneWidget);
      expect(find.text('My Karma Score'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      await tester.tap(find.text('Chore Settings'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'A season is needed to edit your availability and preferences.',
        ),
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
