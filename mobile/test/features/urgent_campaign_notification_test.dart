import 'dart:convert';

import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';
import 'package:chore_wars/features/chat/presentation/widgets/urgent_campaign_notification.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ActionProposalModel campaign({bool camelCase = false}) => ActionProposalModel(
  id: 'campaign',
  houseId: 'house',
  roomId: 'room',
  creatorId: 'alice',
  type: ProposalType.urgentEvent,
  status: ProposalStatus.approved,
  title: 'House Cleaning and Party Preparation',
  description: '',
  payloadJson: jsonEncode({
    camelCase ? 'chores' : 'Chores': [
      for (final task in [
        ('ALICE', 'Wash dishes'),
        ('bob', 'Clean kitchen'),
        ('alice', 'Set table'),
      ])
        {
          camelCase ? 'assignedUserId' : 'AssignedUserId': task.$1,
          camelCase ? 'name' : 'Name': task.$2,
          camelCase ? 'description' : 'Description': 'Prepare for the party',
          camelCase ? 'karmaPoints' : 'KarmaPoints': 10,
        },
    ],
  }),
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
);

void main() {
  Future<void> mount(
    WidgetTester tester,
    ActionProposalModel? proposal, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeUrgentEventForHouseProvider.overrideWith(
            (ref, id) async => proposal,
          ),
          houseMembersProvider.overrideWith(
            (ref, id) async => [
              for (final name in ['Alice', 'Bob'])
                HouseMember(
                  id: name,
                  userId: name.toLowerCase(),
                  displayName: name,
                  role: HouseRole.member,
                  status: HouseMemberStatus.active,
                ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: UrgentCampaignNotification(houseId: 'house'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no bomb when the house has no active campaign', (tester) async {
    await mount(tester, null);
    expect(find.byTooltip('Urgent tasks'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final camelCase in [false, true]) {
    testWidgets('opens tasks grouped by member, camelCase=$camelCase', (
      tester,
    ) async {
      await mount(tester, campaign(camelCase: camelCase));
      expect(find.textContaining('CAMPAIGN ACTIVATED'), findsNothing);
      await tester.tap(find.byTooltip('Urgent tasks'));
      await tester.pumpAndSettle();
      expect(find.textContaining('CAMPAIGN ACTIVATED'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('2 tasks'), findsOneWidget);
      for (final task in ['Wash dishes', 'Clean kitchen', 'Set table']) {
        expect(find.text(task), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Close urgent tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsNothing);
      expect(find.byTooltip('Urgent tasks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('campaign scrolls on a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, campaign(), scale: 2);
    await tester.tap(find.byTooltip('Urgent tasks'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Clean kitchen'), 180);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close urgent tasks'));
    await tester.pumpAndSettle();
  });
}
