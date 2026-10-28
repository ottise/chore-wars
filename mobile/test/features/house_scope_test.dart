import 'dart:typed_data';

import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/house/presentation/screens/house_detail_screen.dart';
import 'package:chore_wars/features/notifications/domain/entities/notification_models.dart';
import 'package:chore_wars/features/notifications/presentation/providers/notification_providers.dart';
import 'package:chore_wars/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:chore_wars/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:chore_wars/features/notifications/presentation/widgets/chat_notification_banner.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

AppNotification notice(String id, String house) => AppNotification.fromJson({
  'id': id,
  'userId': 'me',
  'houseId': house,
  'type': 'CHAT_MESSAGE',
  'title': id,
  'message': 'Message',
  'createdAt': '2026-10-25T10:00:00Z',
});

class _Inbox extends NotificationNotifier {
  final read = <String>[];
  @override
  NotificationState build() => NotificationState(
    notifications: [
      notice('A only', 'A'),
      notice('B first', 'B'),
      notice('B second', 'B'),
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

  void receive(AppNotification item) => state = NotificationState(
    notifications: [...state.notifications, item],
    latestArrival: item,
  );
}

class _NoSeason implements HttpClientAdapter {
  _NoSeason(this.status);
  final int status;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    expect(request.path, '/houses/new-house/seasons/current');
    return ResponseBody.fromString('', status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
    'bell carries house scope and mark all read affects only that house',
    (tester) async {
      final inbox = _Inbox();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: NotificationBell(houseId: 'A')),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, state) => NotificationsScreen(
              houseId: state.uri.queryParameters['houseId'],
            ),
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
      expect(container.read(unreadHouseNotificationCountProvider('A')), 1);
      expect(container.read(unreadHouseNotificationCountProvider('B')), 2);
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NotificationsScreen>(find.byType(NotificationsScreen))
            .houseId,
        'A',
      );
      expect(find.text('A only'), findsOneWidget);
      expect(find.text('B first'), findsNothing);
      await tester.tap(find.text('Mark All Read'));
      await tester.pumpAndSettle();
      expect(inbox.read, ['A only']);
      expect(container.read(unreadHouseNotificationCountProvider('A')), 0);
      expect(container.read(unreadHouseNotificationCountProvider('B')), 2);
      router.go('/notifications?houseId=B');
      await tester.pumpAndSettle();
      expect(find.text('A only'), findsNothing);
      expect(find.text('B first'), findsOneWidget);
    },
  );

  testWidgets(
    'notification banners never mix houses and close when switching',
    (tester) async {
      final inbox = _Inbox();
      final selected = ValueNotifier('A');
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [notificationNotifierProvider.overrideWith(() => inbox)],
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: selected,
                builder: (_, house, _) => ChatNotificationBanner(
                  houseId: house,
                  location: '/houses/$house',
                  child: const Text('Page'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      inbox.receive(notice('Other house arrival', 'B'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      inbox.receive(notice('Current house arrival', 'A'));
      await tester.pumpAndSettle();
      expect(find.text('Current house arrival'), findsOneWidget);
      selected.value = 'B';
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  for (final status in [200, 204]) {
    testWidgets(
      'new household with HTTP $status empty season displays create season instead of a load error',
      (tester) async {
        final dio = Dio()..httpClientAdapter = _NoSeason(status);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(dio),
              userProfileProvider.overrideWith(
                (ref) async => const UserProfile(
                  id: 'me',
                  email: 'me@example.test',
                  displayName: 'Chi',
                ),
              ),
              houseDetailProvider.overrideWith(
                (ref, id) async => House(
                  id: id,
                  name: 'New house',
                  inviteCode: 'TESTCODE',
                  createdAt: DateTime.utc(2026),
                  myRole: HouseRole.owner,
                ),
              ),
              houseMembersProvider.overrideWith((ref, id) async => []),
            ],
            child: const MaterialApp(
              home: HouseDetailScreen(houseId: 'new-house'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Start Your First Season'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Start Your First Season'), findsOneWidget);
        expect(find.text('Create New Season'), findsOneWidget);
        expect(find.textContaining('Couldn’t load'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
