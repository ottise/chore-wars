import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/core/widgets/app_page_frame.dart';
import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';
import 'package:chore_wars/features/chore/presentation/providers/chore_providers.dart';
import 'package:chore_wars/features/chore/presentation/screens/chore_list_screen.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/notifications/presentation/providers/notification_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _QuietInbox extends NotificationNotifier {
  @override
  NotificationState build() => const NotificationState();
}

void main() {
  testWidgets(
    'team sorts dates, keeps former assignee name and filters current member',
    (tester) async {
      tester.view.physicalSize = const Size(354, 643);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(
              options.path,
              '/houses/house-A/seasons/season-A/occurrences',
            );
            handler.resolve(
              Response(
                requestOptions: options,
                data: [
                  {
                    'id': 'later',
                    'choreId': 'c2',
                    'choreName': 'Later task',
                    'assignedUserId': 'owner',
                    'assignedUserDisplayName': 'Chi',
                    'dueDate': '2026-10-27T08:00:00Z',
                    'status': 0,
                    'karmaPoints': 15,
                  },
                  {
                    'id': 'earlier',
                    'choreId': 'c1',
                    'choreName': 'Earlier task',
                    'assignedUserId': 'former',
                    'assignedUserDisplayName': 'Former member',
                    'dueDate': '2026-10-23T08:00:00Z',
                    'status': 0,
                    'karmaPoints': 10,
                  },
                ],
              ),
            );
          },
        ),
      );
      addTearDown(() => dio.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            notificationNotifierProvider.overrideWith(_QuietInbox.new),
            houseDetailProvider.overrideWith(
              (ref, id) async => House(
                id: id,
                name: 'Nhà A',
                inviteCode: 'TESTCODE',
                createdAt: DateTime.utc(2026),
                myRole: HouseRole.owner,
              ),
            ),
            activeSeasonProvider.overrideWith(
              (ref, id) async => {'id': 'season-A', 'status': 2},
            ),
            houseMembersProvider.overrideWith(
              (ref, id) async => [
                const HouseMember(
                  id: 'm1',
                  userId: 'owner',
                  displayName: 'Chi',
                  role: HouseRole.owner,
                  status: HouseMemberStatus.active,
                ),
              ],
            ),
            choreTemplatesProvider.overrideWith((ref, id) async => []),
            myChoresProvider.overrideWith((ref, id) async => []),
            activeUrgentEventForHouseProvider.overrideWith(
              (ref, id) async => null,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ChoreListScreen(houseId: 'house-A'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        AppPageFrame.background,
      );
      final originalBackground = AppTheme.canvas;
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        originalBackground,
      );
      expect(find.text('Former member'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Earlier task')).dy,
        lessThan(tester.getTopLeft(find.text('Later task')).dy),
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Chi'));
      await tester.pumpAndSettle();
      expect(find.text('Earlier task'), findsNothing);
      expect(find.text('Later task'), findsOneWidget);
      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        AppPageFrame.background,
      );
      expect(find.text('Routines'), findsNothing);
      expect(find.text('Add chore'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
