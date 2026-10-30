import 'package:chore_wars/features/ai/data/ai_repository.dart';
import 'package:chore_wars/features/chat/presentation/widgets/ai_urgent_plan_card.dart';
import 'package:chore_wars/features/chat/presentation/widgets/assistant_requests.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Ai extends AiRepository {
  _Ai() : super(Dio());
  final paths = <String>[];
  @override
  Future<Map<String, dynamic>> post(
    String house,
    String path,
    Map<String, dynamic> body,
  ) async {
    paths.add(path);
    if (path == 'urgent/request') {
      expect(body['participantIds'], ['A', 'B']);
      if (body['readyBy'] != null) {
        expect(body['guestCount'], 10);
        expect(body.containsKey('deadlineMinutes'), isFalse);
      } else {
        expect(body['deadlineMinutes'], 60);
      }
      return {
        'id': 'plan',
        'proposal_id': 'proposal',
        'result': {
          'status': 'READY',
          'tasks': [
            {'name': 'Clean table', 'assigned_to': 'B', 'minutes': 15},
          ],
        },
      };
    }
    expect(path, 'recommendations/plan/accept');
    return {'proposal_id': 'proposal'};
  }
}

void main() {
  for (final candidate in [
    {
      'participant_ids': ['A', 'B'],
      'deadline_minutes': 60,
    },
    {
      'participant_ids': ['A', 'B'],
      'ready_by': '2026-10-25T22:00:00+07:00',
      'guest_count': 10,
    },
  ]) {
    testWidgets(
      'AI drafts named assignments and automatically requests participant approval',
      (tester) async {
        final api = _Ai();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiRepositoryProvider.overrideWithValue(api),
              activeSeasonProvider.overrideWith(
                (ref, id) async => {'id': 'season', 'status': 'ACTIVE'},
              ),
              assistantRequestRoomProvider.overrideWith(
                (ref, id) async => 'room',
              ),
              houseMembersProvider.overrideWith(
                (ref, id) async => [
                  const HouseMember(
                    id: 'membership',
                    userId: 'B',
                    displayName: 'B',
                    role: HouseRole.member,
                    status: HouseMemberStatus.active,
                  ),
                ],
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: AiUrgentPlanCard(
                  houseId: 'house',
                  prompt: 'B should clean the table within 60 minutes',
                  candidate: candidate,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Clean table · B · 15 min'), findsOneWidget);
        expect(api.paths, ['urgent/request']);
        expect(
          find.textContaining('Requests sent to Chore → Bonus.'),
          findsOneWidget,
        );
        expect(find.text('Retry sending requests'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
