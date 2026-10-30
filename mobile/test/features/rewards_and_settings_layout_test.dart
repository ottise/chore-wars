import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';
import 'package:chore_wars/core/widgets/house_shell.dart';
import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';
import 'package:chore_wars/features/chat/data/models/chat_room_model.dart';
import 'package:chore_wars/features/chat/data/repositories/chat_repository.dart';
import 'package:chore_wars/features/chat/providers/chat_providers.dart';
import 'package:chore_wars/features/chat/presentation/screens/chat_room_screen.dart';
import 'package:chore_wars/features/chat/presentation/widgets/chat_notification_button.dart';
import 'package:chore_wars/features/chore/domain/entities/chore_models.dart';
import 'package:chore_wars/features/chore/presentation/providers/chore_providers.dart';
import 'package:chore_wars/features/chore/presentation/screens/chore_list_screen.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';
import 'package:chore_wars/features/chat/presentation/screens/assistant_chat_screen.dart';
import 'package:chore_wars/features/notifications/domain/entities/notification_models.dart';
import 'package:chore_wars/features/notifications/presentation/providers/notification_providers.dart';
import 'package:chore_wars/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:chore_wars/features/auth/presentation/screens/profile_screen.dart';

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
import 'package:chore_wars/features/payment/presentation/providers/payment_history_provider.dart';
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

Future<void> mount(
  WidgetTester tester,
  Widget screen, {
  double textScale = 1.2,
}) async {
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
        activeSeasonProvider.overrideWith(
          (ref, id) async => {
            'id': 'season',
            'name': 'Autumn Harmony',
            'status': 2,
          },
        ),
        choreTemplatesProvider.overrideWith((ref, id) async => []),
        chatRepositoryProvider.overrideWithValue(_PreviewChatRepository()),
        chatNotificationsEnabledProvider.overrideWith((ref, id) async => true),
        actionProposalProvider('room').overrideWith(_PreviewProposals.new),
        houseMembersProvider.overrideWith((ref, id) async => []),
        activeUrgentEventForHouseProvider.overrideWith((ref, id) async => null),
        myChoresProvider.overrideWith(
          (ref, id) async => [
            ChoreOccurrence.fromJson({
              'id': 'occurrence',
              'choreId': 'chore',
              'choreName': 'Floor Mopping',
              'dueDate': '2026-10-24T08:00:00Z',
              'status': 2,
              'karmaPoints': 10,
            }),
          ],
        ),
        notificationNotifierProvider.overrideWith(_PreviewNotifications.new),
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
          (ref, id) async => id == 'empty-house'
              ? []
              : [
                  payment('pending', PaymentStatus.pending),
                  payment('paid', PaymentStatus.paid),
                ],
        ),
        paymentHistoryProvider.overrideWith(
          (ref, query) async => {
            'moneyIn': 50000,
            'moneyOut': 0,
            'totalCount': 2,
            'items': [
              if (query.direction != 'IN')
                {
                  'sourceId': 'pending',
                  'source': 'BOUNTY_PAYMENT',
                  'counterparty': 'Pending recipient',
                  'amount': 20000,
                  'direction': 'OUT',
                  'recordedAt': '2026-10-28T10:00:00Z',
                  'status': 'PENDING_CONFIRMATION',
                  'confirmationSource': 'DEBTOR_REPORTED',
                },
              if (query.direction != 'OUT')
                {
                  'sourceId': 'paid',
                  'source': 'BOUNTY_PAYMENT',
                  'counterparty': 'Confirmed sender',
                  'amount': 50000,
                  'direction': 'IN',
                  'recordedAt': '2026-10-28T11:00:00Z',
                  'status': 'CONFIRMED',
                  'confirmationSource': 'RECIPIENT_CONFIRMED',
                },
            ],
          },
        ),
      ],
      child: RepaintBoundary(
        key: _previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home:
              Platform.environment['UI_REVIEW_DIR'] != null &&
                  screen is! NotificationsScreen
              ? HouseShell(
                  houseId: 'house',
                  location: _location(screen),
                  child: screen,
                )
              : screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _location(Widget screen) {
  const base = '/houses/house';
  return switch (screen) {
    ProfileScreen() => '$base/account',
    RewardCatalogScreen() => '$base/rewards',
    AchievementsScreen() => '$base/achievements',
    KarmaHistoryScreen() => '$base/karma/history',
    SeasonRewardScreen() => '$base/seasons/season/rewards',
    LeaderboardScreen() => '$base/seasons/season/leaderboard',
    CreateSeasonScreen() => '$base/seasons/new',
    PaymentObligationsScreen() => '$base/payments',
    ChoreListScreen() => '$base/chores',
    AssistantChatScreen() => '$base/chat/assistant',
    ChatRoomScreen() => '$base/chat/everyone',
    _ => '$base/settings',
  };
}

class _PreviewProposals extends ActionProposalNotifier {
  _PreviewProposals() : super('room');
  @override
  AsyncValue<List<ActionProposalModel>> build() => const AsyncValue.data([]);
}

class _PreviewChatRepository implements ChatRepository {
  @override
  Future<ChatRoomModel> getHouseRoom(String houseId) async =>
      ChatRoomModel(id: 'room', houseId: houseId, name: 'Household');
  @override
  Future<({List<ChatMessageModel> items, int totalCount})> getMessages(
    String roomId, {
    int page = 1,
    int pageSize = 30,
  }) async => (
    items: [
      ChatMessageModel(
        id: 'reply',
        roomId: roomId,
        senderId: 'me',
        senderName: 'Chi',
        content: 'It is almost done. Dinner is ready too!',
        createdAt: DateTime.utc(2026, 10, 24, 16, 41),
      ),
      ChatMessageModel(
        id: 'question',
        roomId: roomId,
        senderId: 'other',
        senderName: 'Housemate',
        content: 'Did anyone start the laundry yet?',
        createdAt: DateTime.utc(2026, 10, 24, 16, 40),
      ),
    ],
    totalCount: 2,
  );
  @override
  Future<void> connectToHub(
    String roomId,
    void Function(ChatMessageModel) onMessageReceived, {
    void Function()? onProposalsChanged,
  }) async {}
  @override
  Future<void> disconnectHub(String roomId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected chat action in layout preview: ${invocation.memberName}',
  );
}

class _PreviewNotifications extends NotificationNotifier {
  @override
  NotificationState build() => NotificationState(
    notifications: [
      AppNotification.fromJson({
        'id': 'bounty',
        'userId': 'me',
        'title': 'New Bounty!',
        'message': 'A new bounty has been posted in your household.',
        'type': 'BOUNTY_CREATED',
        'houseId': 'house',
        'createdAt': '2026-10-24T08:00:00Z',
      }),
      AppNotification.fromJson({
        'id': 'chore',
        'userId': 'me',
        'title': 'Chore Overdue',
        'message': 'An assigned chore is overdue.',
        'type': 'CHORE_OVERDUE',
        'houseId': 'house',
        'createdAt': '2026-10-23T08:00:00Z',
      }),
    ],
  );
}

Future<void> capture(
  WidgetTester tester,
  String? directory,
  String name,
) async {
  if (directory == null) return;
  final boundary =
      _previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final appFont = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      appFont.addFont(
        File('assets/fonts/be_vietnam_pro/BeVietnamPro-$weight.ttf')
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    }
    await appFont.load();
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          null,
        );
  });
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
      const screens = <Widget>[
        LeaderboardScreen(houseId: 'house', seasonId: 'season'),
        SeasonRewardScreen(houseId: 'house', seasonId: 'season'),
        RewardCatalogScreen(houseId: 'house'),
        AchievementsScreen(houseId: 'house'),
        KarmaHistoryScreen(houseId: 'house'),
        CreateSeasonScreen(houseId: 'house'),
        HouseSettingsScreen(houseId: 'house'),
        ProfileScreen(houseId: 'house'),
        NotificationsScreen(),
        ChoreListScreen(houseId: 'house'),
        AssistantChatScreen(houseId: 'house'),
        ChatRoomScreen(houseId: 'house'),
        PaymentObligationsScreen(houseId: 'house'),
      ];
      for (final screen in screens) {
        await mount(tester, screen);
        await capture(tester, previewDir, 'large-${screen.runtimeType}');
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
      tester.view.physicalSize = const Size(390, 844);
      for (final screen in screens) {
        await mount(tester, screen, textScale: 1);
        await capture(tester, previewDir, 'default-${screen.runtimeType}');
        if (screen is ChoreListScreen) {
          await tester.tap(find.text('Mine'));
          await tester.pumpAndSettle();
          await capture(tester, previewDir, 'default-PersonalChores');
        }
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} at default scale',
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
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Spent'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Spent'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee redeemed'), findsOneWidget);
      expect(find.text('Overdue penalty'), findsNothing);
    },
  );

  testWidgets(
    'payment history labels pending transfers without offering receipt actions',
    (tester) async {
      await mount(tester, const PaymentObligationsScreen(houseId: 'house'));
      expect(find.textContaining('Pending confirmation'), findsOneWidget);
      expect(find.text('Confirm Received'), findsNothing);
      await tester.tap(find.text('Money in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pending confirmation'), findsNothing);
      expect(find.textContaining('Recipient confirmed'), findsOneWidget);
      expect(find.text('Confirm Received'), findsNothing);
    },
  );
  testWidgets('chore deep links select Mine and update to Team on navigation', (
    tester,
  ) async {
    await mount(
      tester,
      const ChoreListScreen(houseId: 'house', initialTab: 'mine'),
    );
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    await mount(
      tester,
      const ChoreListScreen(houseId: 'house', initialTab: 'team'),
    );
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    expect(tester.takeException(), isNull);
  });
}
