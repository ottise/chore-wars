import 'package:chore_wars/core/router/app_router.dart';
import 'package:chore_wars/core/storage/secure_storage.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';
import 'package:chore_wars/features/chore/presentation/providers/chore_providers.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/notifications/presentation/providers/notification_providers.dart';
import 'package:chore_wars/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tokens extends SecureStorage {
  @override
  Future<String?> getAccessToken() async => 'session';
}

class _Inbox extends NotificationNotifier {
  @override
  NotificationState build() => const NotificationState();
}

void main() {
  for (final owner in [true, false]) {
    testWidgets(
      'active season routines: owner=$owner has correct create permission',
      (tester) async {
        tester.view.physicalSize = const Size(354, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(_Tokens()),
            notificationNotifierProvider.overrideWith(_Inbox.new),
            userProfileProvider.overrideWith(
              (ref) async => const UserProfile(
                id: 'me',
                email: 'me@example.test',
                displayName: 'Chi',
              ),
            ),
            myHousesProvider.overrideWith((ref) async => []),
            houseMembersProvider.overrideWith((ref, id) async => []),
            houseDetailProvider.overrideWith(
              (ref, id) async => House(
                id: id,
                name: 'S1.07',
                inviteCode: 'CODE',
                createdAt: DateTime.utc(2026),
                myRole: owner ? HouseRole.owner : HouseRole.member,
              ),
            ),
            activeSeasonProvider.overrideWith(
              (ref, id) async => {'id': 'season', 'status': 2},
            ),
            activeUrgentEventForHouseProvider.overrideWith(
              (ref, id) async => null,
            ),
            choreTemplatesProvider.overrideWith((ref, id) async => []),
            myChoresProvider.overrideWith((ref, id) async => []),
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
        router.go('/houses/house/chores');
        await tester.pumpAndSettle();
        expect(find.byType(NotificationBell), findsOneWidget);
        expect(find.text('No Routines Configured Yet'), findsOneWidget);
        expect(
          find.text('Create First Routine'),
          owner ? findsOneWidget : findsNothing,
        );
        expect(find.text('Popular Templates'), findsNothing);
        expect(find.text('Add'), findsNothing);
        if (owner) {
          await tester.tap(find.text('Create First Routine'));
          await tester.pumpAndSettle();
          expect(find.text('Create Routine'), findsOneWidget);
          expect(
            tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
            isTrue,
          );
          router.pop();
          await tester.pumpAndSettle();
          expect(find.text('Weekly Deep Clean'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
