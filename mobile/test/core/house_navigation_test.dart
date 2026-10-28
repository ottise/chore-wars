import 'package:chore_wars/core/router/app_router.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/core/storage/secure_storage.dart';
import 'package:chore_wars/core/widgets/house_shell.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';
import 'package:chore_wars/features/chat/presentation/screens/assistant_chat_screen.dart';
import 'package:chore_wars/features/chat/presentation/screens/chat_room_screen.dart';
import 'package:chore_wars/features/chat/data/repositories/chat_repository.dart';
import 'package:chore_wars/features/chat/data/models/chat_room_model.dart';
import 'package:chore_wars/features/chat/providers/chat_providers.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:chore_wars/features/notifications/presentation/providers/notification_providers.dart';
import 'package:chore_wars/features/notifications/domain/entities/notification_models.dart';

class _Inbox extends NotificationNotifier {
  @override
  NotificationState build() => NotificationState(
    notifications: [
      AppNotification.fromJson({
        'id': 'request',
        'userId': 'me',
        'houseId': 'house-B',
        'title': 'Incoming AI task',
        'message': 'Review the task',
        'type': 'URGENT_EVENT',
        'targetType': 'AI_REQUEST',
        'targetId': 'proposal',
        'isRead': true,
        'createdAt': '2026-10-24T10:00:00Z',
      }),
    ],
  );
}

class _Tokens extends SecureStorage {
  @override
  Future<String?> getAccessToken() async => 'test-session';
}

class _UnavailableChat extends Fake implements ChatRepository {
  @override
  Future<ChatRoomModel> getHouseRoom(String houseId) async =>
      throw StateError('Offline test room');
}

void main() {
  testWidgets('five tabs retain the URL household and mark deep links', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 643);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/houses/house-B/ai/evaluations/run',
      routes: [
        ShellRoute(
          builder: (context, state, child) => HouseShell(
            houseId: state.pathParameters['houseId']!,
            location: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/houses/:houseId',
              builder: (_, _) => const Scaffold(body: Text('Overview')),
              routes: [
                for (final path in [
                  'chores',
                  'chat',
                  'chat/everyone',
                  'ai',
                  'more',
                  'orders',
                  'bounties',
                  'ai/evaluations/:id',
                ])
                  GoRoute(
                    path: path,
                    builder: (_, _) => const Scaffold(body: Text('Section')),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          houseDetailProvider.overrideWith(
            (ref, id) async => House(
              id: id,
              name: 'Nhà B',
              inviteCode: 'TESTCODE',
              createdAt: DateTime.utc(2026),
            ),
          ),
          userProfileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'me',
              email: 'me@example.test',
              displayName: 'You',
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('house-tab-0')),
        matching: find.text('Overview'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('house-tab-4')), findsOneWidget);
    for (final entry in {
      'Chore': '/chores',
      'Chat': '/chat/everyone',
      'Order': '/orders',
      'Bounty': '/bounties',
      'Overview': '',
    }.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/houses/house-B${entry.value}',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('real router opens grouped household menu with one bottom bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(354, 643);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(_Tokens()),
        chatRepositoryProvider.overrideWithValue(_UnavailableChat()),
        notificationNotifierProvider.overrideWith(_Inbox.new),
        userProfileProvider.overrideWith(
          (ref) async => const UserProfile(
            id: 'me',
            email: 'me@example.test',
            displayName: 'You',
          ),
        ),
        myHousesProvider.overrideWith((ref) async => []),
        houseDetailProvider.overrideWith(
          (ref, id) async => House(
            id: id,
            name: 'Gia đình B',
            inviteCode: 'TEST',
            createdAt: DateTime.utc(2026),
            myRole: HouseRole.member,
          ),
        ),
        houseMembersProvider.overrideWith((ref, id) async => []),
        activeSeasonProvider.overrideWith((ref, id) async => null),
        activeUrgentEventForHouseProvider.overrideWith((ref, id) async => null),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/houses/house-B/more');
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('house-tab-$i')), findsOneWidget);
    }
    expect(find.text('Gia đình B'), findsWidgets);
    expect(find.text('House Management'), findsOneWidget);
    expect(find.text('SEASON MANAGEMENT'), findsOneWidget);
    expect(find.text('Create New Season'), findsNothing);
    router.push('/notifications');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Incoming AI task'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantChatScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.go('/houses/house-B/more');
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      router.push('/notifications');
      await tester.pumpAndSettle();
      expect(find.text('System Notifications'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    router.push('/notifications');
    await tester.pump(const Duration(milliseconds: 20));
    router.go('/houses');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    router.go('/houses/house-B/more');
    await tester.pumpAndSettle();
    router.go('/houses/house-B/chat');
    await tester.pumpAndSettle();
    expect(find.byType(ChatRoomScreen), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/houses/house-B/chat/everyone',
    );
    expect(find.text('Private help with chores and schedules'), findsNothing);
    expect(find.text('Household Chat'), findsOneWidget);
    router.go('/houses/house-B/chat/assistant');
    await tester.pumpAndSettle();
    expect(find.byType(AssistantChatScreen), findsOneWidget);
    expect(
      tester
          .widget<AssistantChatScreen>(find.byType(AssistantChatScreen))
          .houseId,
      'house-B',
    );
    expect(find.text('AI Settings'), findsNothing);
    for (final legacyPath in ['ai', 'ai/evaluations/internal-run']) {
      router.go('/houses/house-B/$legacyPath');
      await tester.pumpAndSettle();
      expect(find.byType(AssistantChatScreen), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/houses/house-B/chat/assistant',
      );
    }
    router.go('/houses/house-B/urgent-event');
    await tester.pumpAndSettle();
    expect(find.byType(AssistantChatScreen), findsOneWidget);
    expect(
      tester
          .widget<AssistantChatScreen>(find.byType(AssistantChatScreen))
          .urgentMode,
      isTrue,
    );
    expect(find.text('Campaign Title'), findsNothing);
    expect(find.byKey(const ValueKey('house-tab-0')), findsOneWidget);
    await tester.tap(find.byTooltip('Back to Chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/houses/house-B');
    router.go('/houses/house-B/more');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Switch House'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch House'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/houses');
    expect(find.byKey(const ValueKey('house-tab-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
