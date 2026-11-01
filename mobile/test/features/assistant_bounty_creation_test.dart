import 'package:chore_wars/features/ai/data/ai_repository.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/bounty/domain/entities/bounty.dart';
import 'package:chore_wars/features/bounty/domain/repositories/bounty_repository.dart';
import 'package:chore_wars/features/bounty/presentation/providers/bounty_providers.dart';
import 'package:chore_wars/features/chat/presentation/screens/assistant_chat_screen.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Ai extends AiRepository {
  _Ai({this.askAmount = false}) : super(Dio());
  final bool askAmount;
  final prompts = <String>[];
  @override
  Future<Map<String, dynamic>> post(
    String house,
    String path,
    Map<String, dynamic> body,
  ) async {
    expect(house, 'house');
    expect(path, 'interpret');
    prompts.add(body['text'] as String);
    final missing = askAmount && prompts.length == 1;
    return {
      'intent': 'bounty_create',
      'summary': missing
          ? 'What reward would you like to offer?'
          : 'Review your kitchen bounty.',
      'missing_fields': missing ? ['bounty_amount_vnd'] : [],
      'bounty': {
        'occurrence_id': 'task',
        'chore_name': 'Clean kitchen',
        'amount': missing ? null : 20000,
        'due_at': '2026-11-02T16:59:00Z',
      },
    };
  }
}

class _Bounties extends Fake implements BountyRepository {
  bool fail = false;
  final writes = <double>[];
  @override
  Future<Bounty> createBounty({
    required String houseId,
    required String choreOccurrenceId,
    required double amount,
  }) async {
    expect(houseId, 'house');
    expect(choreOccurrenceId, 'task');
    if (fail) throw StateError('This chore is no longer eligible.');
    writes.add(amount);
    return Bounty(
      id: 'bounty',
      choreOccurrenceId: choreOccurrenceId,
      choreName: 'Clean kitchen',
      postedByUserId: 'me',
      postedByDisplayName: 'Me',
      amount: amount,
      status: BountyStatus.open,
      expiresAt: DateTime.utc(2026, 11, 2),
    );
  }
}

void main() {
  for (final scenario in ['post', 'clarify', 'stale', 'retry']) {
    testWidgets('Assistant posts bounty directly: $scenario', (tester) async {
      final ai = _Ai(askAmount: scenario == 'clarify');
      final bounties = _Bounties()
        ..fail = scenario == 'stale' || scenario == 'retry';
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const AssistantChatScreen(houseId: 'house'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRepositoryProvider.overrideWithValue(ai),
            bountyRepositoryProvider.overrideWithValue(bounties),
            assistantInboxProvider.overrideWith((ref, house) async => []),
            userProfileProvider.overrideWith(
              (ref) async => const UserProfile(
                id: 'me',
                email: 'me@test.com',
                displayName: 'Me',
              ),
            ),
            houseDetailProvider.overrideWith(
              (ref, house) async => House(
                id: house,
                name: 'Home',
                inviteCode: 'TEST',
                createdAt: DateTime.utc(2026),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Đăng bounty lau bếp giúp tôi',
      );
      await tester.tap(find.byTooltip('Send to Assistant'));
      await tester.pumpAndSettle();
      if (scenario == 'clarify') {
        expect(find.text('Review bounty draft'), findsNothing);
        expect(bounties.writes, isEmpty);
        await tester.enterText(find.byType(TextField), 'Thưởng 20k');
        await tester.tap(find.byTooltip('Send to Assistant'));
        await tester.pumpAndSettle();
        expect(ai.prompts.last, contains('Đăng bounty lau bếp giúp tôi'));
        expect(ai.prompts.last, contains('Thưởng 20k'));
      }
      expect(find.text('Create Bounty'), findsNothing);
      expect(find.text('Review bounty draft'), findsNothing);
      expect(find.text('POST BOUNTY'), findsNothing);
      if (scenario == 'stale' || scenario == 'retry') {
        expect(find.text('Bounty posted successfully.'), findsNothing);
        expect(find.text('Bounty was not posted.'), findsOneWidget);
        expect(bounties.writes, isEmpty);
        if (scenario == 'retry') {
          bounties.fail = false;
          await tester.ensureVisible(find.text('Retry posting bounty'));
          await tester.tap(find.text('Retry posting bounty'));
          await tester.pumpAndSettle();
          expect(ai.prompts.length, 1);
          expect(bounties.writes, [20000]);
          expect(find.text('Bounty posted successfully.'), findsOneWidget);
        }
      } else {
        expect(bounties.writes, [20000]);
        expect(find.text('Bounty posted successfully.'), findsOneWidget);
        expect(find.text('View bounty'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Another draft');
        await tester.pumpAndSettle();
        expect(bounties.writes, [20000]);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
