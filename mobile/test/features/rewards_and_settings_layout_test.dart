import 'dart:io';
import 'dart:ui' as ui;

import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/gamification/data/repositories/custom_reward_repository.dart';
import 'package:chore_wars/features/gamification/domain/entities/gamification_models.dart';
import 'package:chore_wars/features/gamification/presentation/providers/custom_reward_providers.dart';
import 'package:chore_wars/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:chore_wars/features/gamification/presentation/screens/leaderboard_screen.dart';
import 'package:chore_wars/features/gamification/presentation/screens/season_reward_screen.dart';
import 'package:chore_wars/features/gamification/presentation/screens/reward_catalog_screen.dart';
import 'package:chore_wars/features/gamification/presentation/screens/achievements_screen.dart';
import 'package:chore_wars/features/gamification/presentation/screens/karma_history_screen.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/house/presentation/screens/create_season_screen.dart';
import 'package:chore_wars/features/house/presentation/screens/house_settings_screen.dart';
import 'package:chore_wars/features/payment/domain/entities/payment_obligation.dart';
import 'package:chore_wars/features/payment/presentation/providers/payment_providers.dart';
import 'package:chore_wars/features/payment/presentation/screens/payment_obligations_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _previewKey = GlobalKey();

PaymentObligation payment(String id, PaymentStatus status) => PaymentObligation(
  id: id,
  debtorUserId: 'other',
  debtorDisplayName: 'Housemate',
  creditorUserId: 'me',
  creditorDisplayName: 'Chi',
  amount: 50000,
  reason: PaymentReason.bountyPayment,
  status: status,
  createdAt: DateTime.utc(2026, 10, 24),
);

Future<void> mount(WidgetTester tester, Widget screen) async {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        expect(options.method, 'GET');
        expect(options.path, '/houses/house/seasons');
        handler.resolve(Response(requestOptions: options, data: []));
      },
    ),
  );
  addTearDown(dio.close);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        dioProvider.overrideWithValue(dio),
        userProfileProvider.overrideWith(
          (ref) async => const UserProfile(
            id: 'me',
            displayName: 'Chi',
            email: 'chi@example.test',
          ),
        ),
        houseDetailProvider.overrideWith(
          (ref, id) async => House(
            id: id,
            name: 'S1.07',
            inviteCode: 'INVITE',
            createdAt: DateTime.utc(2026),
            myRole: HouseRole.owner,
          ),
        ),
        karmaSummaryProvider.overrideWith(
          (ref, id) async => const KarmaSummary(
            current: 210,
            normalChores: 240,
            bonus: 15,
            penalties: -45,
          ),
        ),
        leaderboardProvider.overrideWith(
          (ref, key) async => const [
            SeasonRanking(
              userId: 'me',
              displayName: 'Chi',
              totalKarma: 120,
              rank: 1,
              choresCompleted: 8,
            ),
            SeasonRanking(
              userId: 'other',
              displayName: 'Housemate',
              totalKarma: -50,
              rank: 2,
              choresCompleted: 3,
            ),
          ],
        ),
        seasonRewardsProvider.overrideWith(
          (ref, key) async => [
            SeasonReward(
              id: 'pass',
              name: 'Chore Pass',
              description: 'Skip a chore with reassignment.',
              type: 0,
              status: RedemptionStatus.claimed,
              redemptionId: 'redemption',
              usageDeadline: DateTime.utc(2026, 11, 23),
            ),
          ],
        ),
        customRewardsProvider.overrideWith(
          (ref, id) async => const [
            CustomReward(
              'coffee',
              'Weekend Coffee Delivery',
              'Fresh coffee delivered to your bedroom door on Saturday and Sunday.',
              100,
              true,
            ),
          ],
        ),
        achievementsProvider.overrideWith(
          (ref, id) async => const [
            Achievement(
              id: 'first',
              name: 'First chore',
              description: 'Completed your first chore in this household.',
              conditionType: 0,
              threshold: 1,
              isUnlocked: true,
            ),
            Achievement(
              id: 'karma',
              name: 'Karma collector',
              description: 'Earn Karma from household chores.',
              conditionType: 2,
              threshold: 100,
              isUnlocked: false,
            ),
          ],
        ),
        karmaHistoryProvider.overrideWith(
          (ref, id) async => [
            KarmaTransaction(
              id: 'earned',
              amount: 10,
              type: KarmaTransactionType.choreCompleted,
              createdAt: DateTime.utc(2026, 10, 23),
              description: 'Dishes completed',
            ),
            KarmaTransaction(
              id: 'penalty',
              amount: -5,
              type: KarmaTransactionType.penalty,
              createdAt: DateTime.utc(2026, 10, 24),
              description: 'Overdue penalty',
            ),
            KarmaTransaction(
              id: 'spent',
              amount: -100,
              type: KarmaTransactionType.rewardRedeemed,
              createdAt: DateTime.utc(2026, 10, 22),
              description: 'Coffee redeemed',
            ),
          ],
        ),
        paymentListProvider.overrideWith(
          (ref, id) async => [
            payment('pending', PaymentStatus.pending),
            payment('paid', PaymentStatus.paid),
          ],
        ),
      ],
      child: RepaintBoundary(
        key: _previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: Platform.environment['UI_FONT_PATH'] == null
              ? AppTheme.lightTheme
              : AppTheme.lightTheme.copyWith(
                  appBarTheme: AppTheme.lightTheme.appBarTheme.copyWith(
                    titleTextStyle: AppTheme
                        .lightTheme
                        .appBarTheme
                        .titleTextStyle
                        ?.copyWith(fontFamily: 'Roboto'),
                  ),
                  listTileTheme: AppTheme.lightTheme.listTileTheme.copyWith(
                    titleTextStyle: AppTheme
                        .lightTheme
                        .listTileTheme
                        .titleTextStyle
                        ?.copyWith(fontFamily: 'Roboto'),
                    subtitleTextStyle: AppTheme
                        .lightTheme
                        .listTileTheme
                        .subtitleTextStyle
                        ?.copyWith(fontFamily: 'Roboto'),
                  ),
                ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.2)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'all reference screens render on a narrow phone with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previewDir = Platform.environment['UI_REVIEW_DIR'];
      if (previewDir != null) {
        await tester.runAsync(() async {
          for (final entry in {
            'UI_FONT_PATH': 'Roboto',
            'UI_ICON_FONT_PATH': 'MaterialIcons',
          }.entries) {
            final path = Platform.environment[entry.key];
            if (path == null) continue;
            final loader = FontLoader(entry.value);
            loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
            await loader.load();
          }
          await Directory(previewDir).create(recursive: true);
        });
      }
      for (final screen in const <Widget>[
        LeaderboardScreen(houseId: 'house', seasonId: 'season'),
        SeasonRewardScreen(houseId: 'house', seasonId: 'season'),
        RewardCatalogScreen(houseId: 'house'),
        AchievementsScreen(houseId: 'house'),
        KarmaHistoryScreen(houseId: 'house'),
        CreateSeasonScreen(houseId: 'house'),
        HouseSettingsScreen(houseId: 'house'),
        PaymentObligationsScreen(houseId: 'house'),
      ]) {
        await mount(tester, screen);
        if (previewDir != null) {
          final boundary =
              _previewKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$previewDir/${screen.runtimeType}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(
          tester.takeException(),
          isNull,
          reason: screen.runtimeType.toString(),
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: screen.runtimeType.toString(),
        );
      }
    },
  );

  testWidgets(
    'Karma filters separate earnings, penalties and redeemed rewards',
    (tester) async {
      await mount(tester, const KarmaHistoryScreen(houseId: 'house'));
      await tester.tap(find.text('Penalties (-)'));
      await tester.pumpAndSettle();
      expect(find.text('Overdue penalty'), findsOneWidget);
      expect(find.text('Dishes completed'), findsNothing);
      expect(find.text('Coffee redeemed'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Spent'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee redeemed'), findsOneWidget);
      expect(find.text('Overdue penalty'), findsNothing);
    },
  );

  testWidgets(
    'payment history excludes pending obligations and has no confirm action',
    (tester) async {
      await mount(tester, const PaymentObligationsScreen(houseId: 'house'));
      expect(find.text('Status: Pending'), findsOneWidget);
      expect(find.text('Confirm Received'), findsOneWidget);
      await tester.tap(find.text('Settled History'));
      await tester.pumpAndSettle();
      expect(find.text('Status: Pending'), findsNothing);
      expect(find.text('Status: Recipient confirmed receipt'), findsOneWidget);
      expect(find.text('Confirm Received'), findsNothing);
    },
  );
}
