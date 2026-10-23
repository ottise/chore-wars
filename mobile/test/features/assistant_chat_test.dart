import 'package:chore_wars/features/ai/data/ai_repository.dart';
import 'package:chore_wars/features/chat/presentation/screens/assistant_chat_screen.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends AiRepository {
  _Repository() : super(Dio());
  bool enabled = true;
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> get(String house, String path) async => {
    'configured': true,
    'enabled': enabled,
  };
  @override
  Future<Map<String, dynamic>> post(
    String house,
    String path,
    Map<String, dynamic> body,
  ) async {
    calls.add('$house/$path:${body['text']}');
    return {'summary': 'You bận vào tối mai.', 'missing_fields': <String>[]};
  }
}

void main() {
  testWidgets(
    'private assistant uses household API and keeps draft while unavailable',
    (tester) async {
      final repository = _Repository()..enabled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRepositoryProvider.overrideWithValue(repository),
            houseDetailProvider.overrideWith(
              (ref, id) async => House(
                id: id,
                name: 'Nhà B',
                inviteCode: 'TESTCODE',
                createdAt: DateTime.utc(2026),
              ),
            ),
          ],
          child: const MaterialApp(
            home: AssistantChatScreen(houseId: 'house-B'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Tối mai tôi bận');
      await tester.tap(find.byTooltip('Send to Assistant'));
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);
      expect(
        find.textContaining('The assistant is unavailable'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Tối mai tôi bận',
      );
      repository.enabled = true;
      await tester.tap(find.byTooltip('Send to Assistant'));
      await tester.pumpAndSettle();
      expect(repository.calls, ['house-B/interpret:Tối mai tôi bận']);
      expect(find.text('You bận vào tối mai.'), findsOneWidget);
      expect(find.text('Tối mai tôi bận'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
