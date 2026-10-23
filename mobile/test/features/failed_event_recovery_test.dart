import 'package:chore_wars/features/house/data/repositories/failed_event_repository.dart';
import 'package:chore_wars/features/house/presentation/screens/failed_events_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RecoveryRepository extends FailedEventRepository {
  RecoveryRepository() : super(Dio());
  int replays = 0;
  String status = 'FAILED';
  @override
  Future<FailedEventPage> list(String house, String? filter, int page) async =>
      FailedEventPage.fromJson({
        'items': filter == null || filter == status
            ? [
                {
                  'id': 'event-1',
                  'topic': 'chore.completed',
                  'status': status,
                  'errorCode': 'TimeoutException',
                  'failureCount': 1,
                  'replayCount': replays,
                  'lastFailedAt': '2026-10-20T08:00:00Z',
                },
              ]
            : [],
        'total': filter == null || filter == status ? 1 : 0,
      });
  @override
  Future<void> replay(String house, String id) async {
    replays++;
    status = 'REPLAY_REQUESTED';
  }
}

void main() {
  testWidgets(
    'owner replay needs confirmation and queued event cannot be submitted again',
    (tester) async {
      final repository = RecoveryRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            failedEventRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: FailedEventsScreen(houseId: 'house-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry Processing'), findsOneWidget);
      await tester.tap(find.text('Retry Processing'));
      await tester.pumpAndSettle();
      expect(repository.replays, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.replays, 0);
      await tester.tap(find.text('Retry Processing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.replays, 1);
      expect(find.text('Retry Processing'), findsNothing);
      expect(find.text('No requests with this status.'), findsOneWidget);
    },
  );
}
