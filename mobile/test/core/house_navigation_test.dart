import 'package:chore_wars/core/router/app_router.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/core/storage/secure_storage.dart';
import 'package:chore_wars/core/widgets/house_shell.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';
import 'package:chore_wars/features/chat/presentation/screens/assistant_chat_screen.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Tokens extends SecureStorage {
  @override
  Future<String?> getAccessToken() async => 'test-session';
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
                  'ai',
                  'more',
                  'bonus',
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
      'Chat': '/chat',
      'Bonus': '/bonus',
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
    router.go('/houses/house-B/chat');
    await tester.pumpAndSettle();
    expect(find.text('AI Assistant'), findsOneWidget);
    expect(find.text('Household Chat'), findsOneWidget);
    await tester.tap(find.text('AI Assistant'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantChatScreen), findsOneWidget);
    expect(
      tester
          .widget<AssistantChatScreen>(find.byType(AssistantChatScreen))
          .houseId,
      'house-B',
    );
    expect(find.text('AI Settings'), findsOneWidget);
    expect(find.byKey(const ValueKey('house-tab-0')), findsNothing);
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
