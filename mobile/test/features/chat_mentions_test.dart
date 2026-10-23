import 'package:chore_wars/features/chat/domain/chat_mentions.dart';
import 'package:chore_wars/features/chat/presentation/widgets/message_input.dart';
import 'package:chore_wars/features/chat/presentation/widgets/chat_send_error_message.dart';
import 'package:chore_wars/features/house/domain/entities/invite_code.dart';
import 'package:chore_wars/features/notifications/domain/entities/notification_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_netcore/errors.dart';

void main() {
  const member = '3220da72-77de-405c-8d7e-dba9fdd463c3';
  test(
    'mentions keep stable IDs and render names without leaking identifiers',
    () {
      expect(
        displayChatMentions('@{$member} @all @agent giúp mình', {member: 'An'}),
        '@An @Everyone @Assistant giúp mình',
      );
      expect(
        chatAgentPrompt('@agent @{$member} tối nay tôi bận'),
        'tối nay tôi bận',
      );
      expect(chatAgentMentionPattern.hasMatch('email@agent.example'), isFalse);
    },
  );
  test('QR only accepts invite codes or codes within invitation links', () {
    expect(parseInviteCode(' ab12cd34 '), 'AB12CD34');
    expect(
      parseInviteCode('https://example.test/join?code=ab12cd34'),
      'AB12CD34',
    );
    expect(parseInviteCode('https://example.test/other'), isNull);
    expect(parseInviteCode('not a house code'), isNull);
  });
  test('notification routing retains server household and target scope', () {
    final item = AppNotification.fromJson({
      'id': 'n',
      'userId': 'u',
      'type': 'CHAT_MENTION',
      'houseId': 'house',
      'targetId': 'room',
      'targetType': 'CHAT_ROOM',
      'title': 'Mention',
      'message': 'Open chat',
      'createdAt': '2026-10-23T00:00:00Z',
    });
    expect(item.houseId, 'house');
    expect(item.isChat, isTrue);
    expect(item.asRead().houseId, 'house');
  });
  testWidgets(
    'at button offers agent, everyone and members; sends stable member mention',
    (tester) async {
      String? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MessageInput(
                mentionTargets: const [
                  ChatMentionTarget(id: 'agent', label: 'Assistant'),
                  ChatMentionTarget(id: 'all', label: 'Everyone'),
                  ChatMentionTarget(id: member, label: 'An'),
                ],
                onSendMessage: (value) async {
                  sent = value;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Mention'));
      await tester.pumpAndSettle();
      expect(find.text('@Assistant'), findsOneWidget);
      expect(find.text('@Everyone'), findsNWidgets(2));
      await tester.tap(find.text('@An'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Giúp mình rửa chén');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(sent, '@{$member} Giúp mình rửa chén');
      expect(find.byType(InputChip), findsNothing);
    },
  );
  testWidgets(
    'everyone shortcut keeps a failed draft and can retry mention only',
    (tester) async {
      tester.view.physicalSize = const Size(354, 643);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sent = <String>[];
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MessageInput(
                mentionTargets: const [
                  ChatMentionTarget(id: 'all', label: 'Everyone'),
                ],
                voiceRecorder: const SizedBox(width: 144, height: 48),
                onSendMessage: (content) async {
                  sent.add(content);
                  if (fail) throw GeneralError("Unknown hub method 'SendText'");
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('chat-mention-all')));
      await tester.pump();
      await tester.tap(find.byTooltip('Send Message'));
      await tester.pumpAndSettle();
      expect(sent, ['@all']);
      expect(find.byType(InputChip), findsOneWidget);
      expect(
        find.textContaining('Chat requires a backend update'),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(find.byTooltip('Send Message'));
      await tester.pumpAndSettle();
      expect(sent, ['@all', '@all']);
      expect(find.byType(InputChip), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('chat transport errors explain recovery without exposing internals', () {
    expect(
      chatSendErrorMessage(StateError('offline')),
      contains('Chat is disconnected'),
    );
    expect(
      chatSendErrorMessage(
        GeneralError('Only active members of this household can be mentioned.'),
      ),
      contains('has left the house'),
    );
    expect(
      chatSendErrorMessage(GeneralError('private database diagnostic')),
      isNot(contains('private database')),
    );
  });
  testWidgets(
    'agent receives only the explicit request after the message is sent',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageInput(
              mentionTargets: const [
                ChatMentionTarget(id: 'agent', label: 'Assistant'),
              ],
              onSendMessage: (value) async {
                calls.add('sent:$value');
              },
              onAgentRequest: (value) async {
                calls.add('agent:$value');
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Mention'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('@Assistant'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tối mai tôi bận');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(calls, ['sent:@agent Tối mai tôi bận', 'agent:Tối mai tôi bận']);
    },
  );
}
