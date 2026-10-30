import 'package:chore_wars/features/notifications/domain/entities/notification_models.dart';
import 'package:chore_wars/features/notifications/presentation/providers/notification_providers.dart';
import 'package:chore_wars/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:chore_wars/features/notifications/presentation/widgets/chat_notification_banner.dart';
import 'package:chore_wars/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

AppNotification _notice(
  String id,
  String type, {
  String? targetType,
  String? targetId,
}) => AppNotification.fromJson({
  'id': id,
  'userId': 'member',
  'title': id,
  'message': 'Open household chat',
  'type': type,
  'houseId': 'house-A',
  'targetType': targetType,
  'targetId': targetId,
  'createdAt': '2026-10-24T08:00:00Z',
});

class _Inbox extends NotificationNotifier {
  _Inbox({this.initial = const []});
  final List<AppNotification> initial;
  final read = <String>[];
  @override
  NotificationState build() => NotificationState(notifications: initial);
  void receive(AppNotification notification) {
    state = NotificationState(
      notifications: [notification, ...state.notifications],
      latestArrival: notification,
    );
  }

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
    'incoming AI task request shows a banner and opens private Assistant',
    (tester) async {
      final inbox = _Inbox();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: ChatNotificationBanner(
                location: '/houses/house-A',
                child: SizedBox(),
              ),
            ),
          ),
          GoRoute(
            path: '/houses/house-A/chat/assistant',
            builder: (_, _) =>
                const Scaffold(body: Text('Assistant task inbox')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [notificationNotifierProvider.overrideWith(() => inbox)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      inbox.receive(
        _notice(
          'Party preparation request',
          'URGENT_EVENT',
          targetType: 'AI_REQUEST',
          targetId: 'proposal',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Party preparation request'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Assistant task inbox'), findsOneWidget);
      expect(inbox.read, ['Party preparation request']);
    },
  );
  test(
    'notification destinations use known target types and encoded identifiers',
    () {
      expect(
        _notice(
          'request',
          'URGENT_EVENT',
          targetType: 'AI_REQUEST',
          targetId: 'proposal',
        ).destination,
        '/houses/house-A/chat/assistant',
      );
      expect(
        _notice(
          'n',
          'CHORE_OVERDUE',
          targetType: 'CHORE',
          targetId: 'task',
        ).destination,
        '/houses/house-A/chores/task',
      );
      expect(
        _notice(
          'n',
          'BOUNTY_CREATED',
          targetType: 'BOUNTY',
          targetId: 'bounty',
        ).destination,
        '/bounties/bounty?houseId=house-A',
      );
      expect(
        _notice('n', 'CHAT_MESSAGE').destination,
        '/houses/house-A/chat/everyone',
      );
      expect(
        _notice(
          'n',
          'UNKNOWN',
          targetType: 'https://elsewhere',
          targetId: 'id',
        ).destination,
        isNull,
      );
      expect(
        _notice('n', 'CHORE_OVERDUE', targetType: 'CHORE').destination,
        isNull,
      );
      expect(
        _notice(
          'n',
          'CHORE_OVERDUE',
          targetType: 'CHORE',
          targetId: 'task/other',
        ).destination,
        '/houses/house-A/chores/task%2Fother',
      );
    },
  );

  testWidgets(
    'new chat shows banner and unread badge; Open navigates and marks read',
    (tester) async {
      final inbox = _Inbox(initial: [_notice('old-message', 'CHAT_MESSAGE')]);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              appBar: null,
              body: ChatNotificationBanner(
                location: '/',
                child: NotificationBell(),
              ),
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/houses/house-A/chat/everyone',
            builder: (_, _) => const Scaffold(body: Text('Conversation')),
          ),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [notificationNotifierProvider.overrideWith(() => inbox)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(container.read(unreadNotificationCountProvider), 0);
      inbox.receive(_notice('New household message', 'CHAT_MESSAGE'));
      await tester.pumpAndSettle();
      expect(find.text('New household message'), findsOneWidget);
      expect(container.read(unreadNotificationCountProvider), 0);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Conversation'), findsOneWidget);
      expect(inbox.read, ['New household message']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('viewing the same chat does not show a duplicate banner', (
    tester,
  ) async {
    final inbox = _Inbox();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationNotifierProvider.overrideWith(() => inbox)],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatNotificationBanner(
              location: '/houses/house-A/chat/everyone',
              child: SizedBox(),
            ),
          ),
        ),
      ),
    );
    inbox.receive(_notice('New message', 'CHAT_MESSAGE'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('notification card opens the actual chore detail', (
    tester,
  ) async {
    final inbox = _Inbox(
      initial: [
        _notice(
          'Overdue chore',
          'CHORE_OVERDUE',
          targetType: 'CHORE',
          targetId: 'task',
        ),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const NotificationsScreen()),
        GoRoute(
          path: '/houses/house-A/chores/task',
          builder: (_, _) => const Scaffold(body: Text('Task detail')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationNotifierProvider.overrideWith(() => inbox)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Details →'));
    await tester.pumpAndSettle();
    expect(find.text('Task detail'), findsOneWidget);
    expect(inbox.read, ['Overdue chore']);
  });
}
