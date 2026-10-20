import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chore_wars/features/chat/data/models/chat_message_model.dart';
import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';
import 'package:chore_wars/features/chat/presentation/widgets/interactive_action_card.dart';

void main() {
  test('legacy text messages and typed audio both decode', () {
    final json = {
      'id': 'message',
      'roomId': 'room',
      'senderId': 'user',
      'senderName': 'A',
      'content': 'hello',
      'createdAt': '2026-10-19T00:00:00Z',
    };
    expect(ChatMessageModel.fromJson(json).messageType, 'TEXT');
    expect(
      ChatMessageModel.fromJson({
        ...json,
        'messageType': 'AUDIO',
        'attachmentId': 'audio',
      }).attachmentId,
      'audio',
    );
  });
  testWidgets('deferred proposal card cannot execute an action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: InteractiveActionCard(
              proposal: ActionProposalModel(
                id: 'p',
                title: 'Swap',
                description: 'Existing proposal',
                status: ProposalStatus.pending,
                houseId: 'h',
                roomId: 'r',
                creatorId: 'c',
                payloadJson: '{}',
                createdAt: DateTime.utc(2026),
                type: ProposalType.seasonApproval,
              ),
              currentUserId: 'user',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Swap'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('unavailable'), findsOneWidget);
  });
}
