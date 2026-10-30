import 'package:chore_wars/core/utils/vietnam_time.dart';
import 'package:chore_wars/features/chore/data/repositories/mock_chore_repository.dart';
import 'package:chore_wars/features/chore/domain/entities/chore_models.dart';
import 'package:chore_wars/features/chore/presentation/providers/chore_providers.dart';
import 'package:chore_wars/features/chore/presentation/screens/legacy_chore_redirect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Repository extends MockChoreRepository {
  int loads = 0;
  @override
  Future<ChoreOccurrence> getOccurrence(String id) async {
    loads++;
    return ChoreOccurrence.fromJson({
      'id': id,
      'choreId': 'definition',
      'houseId': 'actual-house',
      'seasonId': 'historical-season',
      'seasonName': 'Previous season',
      'choreName': 'Actual chore',
      'dueDate': '2026-10-30T20:30:00Z',
      'canComplete': true,
      'canUploadEvidence': true,
      'status': 'OVERDUE',
    });
  }

  @override
  Future<List<ChoreTemplate>> getHouseChores(String house) => throw StateError(
    'Current season definitions must not be needed to open a historical occurrence.',
  );
}

void main() {
  test(
    'Vietnam display is independent of device timezone and crosses midnight',
    () {
      final date = vietnamTime('2026-10-30T20:30:00Z');
      expect(
        [date.year, date.month, date.day, date.hour, date.minute],
        [2026, 10, 31, 3, 30],
      );
      expect(date, vietnamTime('2026-10-31T03:30:00+07:00'));
      for (final invalid in [
        null,
        '',
        'bad',
        '2026-10-30T20:30:00',
        '2026-02-30T00:00:00Z',
      ]) {
        expect(() => vietnamTime(invalid), throwsFormatException);
      }
    },
  );

  test('direct occurrence detail needs no current season definition and rejects wrong house', () async {
    final container = ProviderContainer(
      overrides: [choreRepositoryProvider.overrideWithValue(_Repository())],
    );
    addTearDown(container.dispose);
    final detail = await container.read(
      choreDetailProvider((houseId: 'actual-house', occurrenceId: 'occurrence'))
          .future,
    );
    expect(detail.occurrence.choreName, 'Actual chore');
    expect(detail.occurrence.seasonName, 'Previous season');
    expect(detail.occurrence.canComplete, isTrue);
    await expectLater(
      container.read(
        choreDetailProvider((
          houseId: 'wrong-house',
          occurrenceId: 'occurrence',
        )).future,
      ),
      throwsStateError,
    );
  });

  testWidgets(
    'legacy deep link resolves actual house instead of trusting stale query',
    (tester) async {
      final repository = _Repository();
      final router = GoRouter(
        initialLocation: '/chores/occurrence?houseId=wrong-house&name=Wrong',
        routes: [
          GoRoute(
            path: '/chores/:id',
            builder: (_, state) => LegacyChoreRedirectScreen(
              occurrenceId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/houses/:house/chores/:id',
            builder: (_, state) => Scaffold(
              body: Text(
                '${state.pathParameters['house']}/${state.pathParameters['id']}',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [choreRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('actual-house/occurrence'), findsOneWidget);
      expect(repository.loads, 1);
    },
  );
}
