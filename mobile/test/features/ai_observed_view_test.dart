import 'package:chore_wars/core/storage/session_provider.dart';
import 'package:chore_wars/features/ai/data/ai_repository.dart';
import 'package:chore_wars/features/ai/presentation/ai_observed_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class Observations extends AiRepository {
  Observations() : super(Dio());
  final requests = <String>[];
  @override
  Future<bool> observe(
    String house,
    String request,
    String entity,
    String kind,
  ) async {
    requests.add(request);
    return true;
  }
}

void main() {
  testWidgets(
    'one actual view remains one observation across rebuilds and session changes',
    (tester) async {
      final repository = Observations();
      final container = ProviderContainer(
        overrides: [aiRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      Widget screen(String text) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AiObservedView(
            house: 'house',
            entity: 'task',
            kind: AiObservedView.taskOpened,
            child: Text(text),
          ),
        ),
      );
      await tester.pumpWidget(screen('Loaded'));
      await tester.pump();
      expect(repository.requests.length, 1);
      await tester.pumpWidget(screen('Updated'));
      await tester.pump();
      expect(repository.requests.length, 1);
      container.read(sessionEpochProvider.notifier).advance();
      await tester.pump();
      await tester.pump();
      expect(repository.requests.length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
