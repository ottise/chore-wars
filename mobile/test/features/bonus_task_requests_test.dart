import 'package:chore_wars/core/widgets/assistant_shortcut.dart';
import 'package:chore_wars/features/chat/presentation/screens/assistant_chat_screen.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/notifications/domain/entities/notification_models.dart';
import 'package:chore_wars/features/notifications/presentation/providers/notification_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';
import 'package:chore_wars/features/chat/data/services/action_proposal_service.dart';
import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/chat/data/models/chat_room_model.dart';
import 'package:chore_wars/features/chat/data/repositories/chat_repository.dart';
import 'package:chore_wars/features/chat/providers/chat_providers.dart';
import 'package:chore_wars/features/house/presentation/screens/bonus_chores_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Chat extends Fake implements ChatRepository {
  @override
  Future<ChatRoomModel> getHouseRoom(String houseId) async =>
      const ChatRoomModel(id: 'room', houseId: 'house', name: 'Family');
}

class _Auth extends AuthStateNotifier {
  _Auth(this.user);
  final String user;
  @override
  AuthState build() => AuthAuthenticated(
    AuthUser(
      userId: user,
      displayName: user,
      accessToken: 'test',
      refreshToken: 'test',
    ),
  );
}

class _Api implements HttpClientAdapter {
  bool approved = false;
  bool rejected = false;
  bool failResponse = false;
  bool failRequests = false;
  bool expired = false;
  String target = 'recipient';
  String proposalType = 'URGENT_EVENT';
  String status = 'PENDING';
  int reads = 0;
  final posts = <Map<String, dynamic>>[];
  Map<String, dynamic> proposal() => {
    'id': 'invite',
    'houseId': 'house',
    'roomId': 'room',
    'creatorId': 'creator',
    'type': proposalType,
    'creatorName': 'Chi',
    'status': rejected
        ? 'REJECTED'
        : approved
        ? 'APPROVED'
        : 'PENDING',
    'title': 'Prepare dinner',
    'description': 'Shared preparation',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'expiresAt': DateTime.now()
        .toUtc()
        .add(Duration(hours: expired ? -1 : 1))
        .toIso8601String(),
    'payloadJson': jsonEncode({
      'DeadlineMinutes': 60,
      'Chores': [
        {
          'Name': 'Wash vegetables',
          'Description': 'Rinse before cooking',
          'KarmaPoints': 10,
          'AssignedUserId': target,
        },
        {'Name': 'Cook rice', 'KarmaPoints': 10, 'AssignedUserId': 'creator'},
      ],
    }),
    'confirmations': [
      {'id': 'confirmation', 'targetUserId': target, 'status': status},
    ],
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic data = [];
    var code = 200;
    if (options.path.endsWith('/assistant/requests')) {
      data = [proposal()];
    } else if (options.path.endsWith('/proposals/active')) {
      reads++;
      if (failRequests) {
        code = 503;
        data = {'message': 'Unavailable'};
      } else {
        data = [proposal()];
      }
    } else if (options.path.endsWith('/respond')) {
      posts.add(Map<String, dynamic>.from(options.data as Map));
      if (failResponse) {
        code = 503;
        data = {'message': 'Unavailable'};
      } else {
        rejected = options.data['status'] == 'REJECTED';
        approved = !rejected;
        status = rejected ? 'REJECTED' : 'CONFIRMED';
        data = proposal();
      }
    } else if (options.path.endsWith('/occurrences') && approved) {
      data = [
        {
          'id': 'new-work',
          'choreName': 'Wash vegetables',
          'type': 'BONUS',
          'assignedUserId': target,
          'status': 'ASSIGNED',
          'dueDate': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'karmaPoints': 10,
        },
      ];
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Notices extends NotificationNotifier {
  _Notices({this.count = 1});
  final int count;
  final read = <String>[];
  @override
  NotificationState build() => NotificationState(
    notifications: [
      for (var i = 0; i < count; i++)
        AppNotification.fromJson({
          'id': 'notice-$i',
          'userId': 'recipient',
          'houseId': 'house',
          'title': 'Your AI assistant has a request',
          'message': 'Prepare dinner',
          'type': 'AI_REQUEST',
          'targetType': 'AI_REQUEST',
          'targetId': 'invite',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
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

class _DelayedProposals extends ActionProposalService {
  _DelayedProposals(this.api) : super(Dio());
  final _Api api;
  Completer<List<ActionProposalModel>>? pending;
  @override
  Future<List<ActionProposalModel>> getActiveProposals(String roomId) async =>
      pending == null
      ? [ActionProposalModel.fromJson(api.proposal())]
      : pending!.future;
  @override
  Future<ActionProposalModel> respondProposal({
    required String proposalId,
    required ProposalConfirmationStatus status,
    String? reason,
  }) async {
    api.approved = true;
    return ActionProposalModel.fromJson(api.proposal());
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Api api, {
  String user = 'recipient',
  double width = 354,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dio = Dio()..httpClientAdapter = api;
  addTearDown(dio.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        chatRepositoryProvider.overrideWithValue(_Chat()),
        authStateProvider.overrideWith(() => _Auth(user)),
        // The invitation must remain usable before the profile request completes.
        userProfileProvider.overrideWith(
          (ref) => Completer<UserProfile>().future,
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: BonusChoresScreen(
            houseId: 'house',
            seasonId: 'season',
            embedded: true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'an older poll cannot restore Confirm after a successful response',
    () async {
      final api = _Api();
      final service = _DelayedProposals(api);
      final container = ProviderContainer(
        overrides: [actionProposalServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(actionProposalProvider('room'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final stale = ActionProposalModel.fromJson(api.proposal());
      service.pending = Completer<List<ActionProposalModel>>();
      final notifier = container.read(actionProposalProvider('room').notifier);
      final poll = notifier.loadProposals();
      await notifier.respondProposal(
        proposalId: 'invite',
        status: ProposalConfirmationStatus.confirmed,
      );
      service.pending!.complete([stale]);
      await poll;
      expect(
        container
            .read(actionProposalProvider('room'))
            .requireValue
            .single
            .status,
        ProposalStatus.approved,
      );
    },
  );

  testWidgets(
    'recipient confirms in Bonus; assigned bonus appears without Claim',
    (tester) async {
      final api = _Api();
      await _mount(tester, api, width: 320);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.textContaining('Wash vegetables'), findsOneWidget);
      expect(find.textContaining('Cook rice'), findsNothing);
      expect(find.text('Claim'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Confirm'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(api.posts.single['status'], 'CONFIRMED');
      expect(find.text('Confirm'), findsNothing);
      expect(find.text('Wash vegetables'), findsOneWidget);
      expect(find.text('View chore'), findsOneWidget);
      expect(find.text('Claim'), findsNothing);
      expect(find.text('Confirmed. Your bonus work is ready.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unavailable rejects invitation without assigning bonus work', (
    tester,
  ) async {
    final api = _Api();
    await _mount(tester, api);
    await tester.ensureVisible(find.text('Unavailable'));
    await tester.tap(find.text('Unavailable'));
    await tester.pumpAndSettle();
    expect(api.posts.single['status'], 'REJECTED');
    expect(find.text('Confirm'), findsNothing);
    expect(find.text('View chore'), findsNothing);
    expect(
      find.text('Request declined. No bonus work was created.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'waiting recipient sees bonus work when another participant confirms',
    (tester) async {
      final api = _Api()..status = 'CONFIRMED';
      await _mount(tester, api);
      expect(find.text('View chore'), findsNothing);
      api.approved = true;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('View chore'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
      expect(find.text('Claim'), findsNothing);
    },
  );

  for (final type in ['URGENT_EVENT', 'CHORE_SWAP', 'SCHEDULE_REPLAN']) {
    testWidgets(
      'private AI receives $type, clears its badge and confirms from conversation',
      (tester) async {
        final api = _Api()..proposalType = type;
        final notices = _Notices();
        final dio = Dio()..httpClientAdapter = api;
        addTearDown(dio.close);
        tester.view.physicalSize = const Size(354, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  const Scaffold(body: AssistantShortcut(houseId: 'house')),
            ),
            GoRoute(
              path: '/houses/house/chat/assistant',
              builder: (_, _) => const AssistantChatScreen(houseId: 'house'),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(dio),
              chatRepositoryProvider.overrideWithValue(_Chat()),
              notificationNotifierProvider.overrideWith(() => notices),
              authStateProvider.overrideWith(() => _Auth('recipient')),
              userProfileProvider.overrideWith(
                (ref) async => const UserProfile(
                  id: 'recipient',
                  displayName: 'Dat',
                  email: 'dat@example.test',
                ),
              ),
              houseDetailProvider.overrideWith(
                (ref, id) async => House(
                  id: id,
                  name: 'Family',
                  inviteCode: 'TEST',
                  createdAt: DateTime.utc(2026),
                ),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);
        await tester.tap(find.byTooltip('AI Assistant, 1 unread requests'));
        await tester.pumpAndSettle();
        expect(find.text('Your assistant · Requests'), findsOneWidget);
        expect(find.text('Confirm'), findsOneWidget);
        expect(notices.read, ['notice-0']);
        expect(notices.state.notifications.single.isRead, isTrue);
        await tester.ensureVisible(find.text('Confirm'));
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(api.posts.single['status'], 'CONFIRMED');
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Confirmed. Changes applied.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('AI unread badge caps at 10+ and does not count in system bell', (
    tester,
  ) async {
    final notices = _Notices(count: 11);
    final container = ProviderContainer(
      overrides: [notificationNotifierProvider.overrideWith(() => notices)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AssistantShortcut(houseId: 'house')),
        ),
      ),
    );
    expect(find.text('10+'), findsOneWidget);
    expect(container.read(unreadNotificationCountProvider), 0);
    expect(container.read(unreadAssistantCountProvider('other-house')), 0);
  });

  testWidgets('creator waits and cannot confirm for recipient', (tester) async {
    await _mount(tester, _Api(), user: 'creator');
    expect(
      find.text('Waiting for invited members to confirm.'),
      findsOneWidget,
    );
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('unrelated member and expired invitation cannot confirm', (
    tester,
  ) async {
    await _mount(tester, _Api()..target = 'someone-else');
    expect(find.text('Confirm'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await _mount(tester, _Api()..expired = true);
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('confirmed participant waits for remaining participants', (
    tester,
  ) async {
    await _mount(tester, _Api()..status = 'CONFIRMED');
    expect(
      find.text('Confirmed. Waiting for the other participants.'),
      findsOneWidget,
    );
    expect(find.text('Confirm'), findsNothing);
    expect(find.text('View chore'), findsNothing);
  });

  testWidgets(
    'failed confirmation stays retryable without success or bonus work',
    (tester) async {
      final api = _Api()..failResponse = true;
      await _mount(tester, api);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Confirmed. Your bonus work is ready.'), findsNothing);
      expect(find.text('View chore'), findsNothing);
      expect(api.posts, hasLength(1));
    },
  );

  testWidgets('request error offers retry and stops automatic retry storm', (
    tester,
  ) async {
    final api = _Api()..failRequests = true;
    await _mount(tester, api);
    expect(find.text('Retry task requests'), findsOneWidget);
    final reads = api.reads;
    await tester.pump(const Duration(seconds: 31));
    expect(api.reads, reads);
    api.failRequests = false;
    await tester.tap(find.text('Retry task requests'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
  });
}
