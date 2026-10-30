import 'package:chore_wars/features/bounty/domain/entities/bounty.dart';
import 'package:chore_wars/features/bounty/domain/repositories/bounty_repository.dart';
import 'package:chore_wars/features/bounty/presentation/providers/bounty_providers.dart';
import 'package:chore_wars/features/bounty/presentation/screens/create_bounty_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Repository extends Fake implements BountyRepository {
  int writes = 0;
  @override
  Future<Bounty> createBounty({
    required String houseId,
    required String choreOccurrenceId,
    required double amount,
  }) async {
    writes++;
    return Bounty(
      id: 'b',
      choreOccurrenceId: choreOccurrenceId,
      choreName: 'Task',
      postedByUserId: 'me',
      postedByDisplayName: 'Me',
      amount: amount,
      status: BountyStatus.open,
      expiresAt: DateTime.utc(2026, 11),
    );
  }
}

void main() {
  for (final submit in [false, true]) {
    testWidgets(
      'direct bounty create ${submit ? 'success' : 'back'} returns to its house board without a pop error',
      (tester) async {
        final repository = _Repository();
        final router = GoRouter(
          initialLocation: '/bounties/create',
          routes: [
            GoRoute(
              path: '/bounties/create',
              builder: (_, _) => const CreateBountyScreen(
                houseId: 'house-A',
                occurrenceId: 'o',
                choreName: 'Task',
                deadline: null,
              ),
            ),
            GoRoute(
              path: '/houses/:house/bounties',
              builder: (_, state) => Scaffold(
                body: Text('Board ${state.pathParameters['house']}'),
              ),
            ),
            GoRoute(
              path: '/bounties',
              builder: (_, state) => Scaffold(
                body: Text('Board ${state.uri.queryParameters['houseId']}'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [bountyRepositoryProvider.overrideWithValue(repository)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        if (submit) {
          await tester.enterText(find.byType(TextFormField), '50000');
          await tester.ensureVisible(find.text('POST BOUNTY'));
          await tester.tap(find.text('POST BOUNTY'));
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();
        expect(find.text('Board house-A'), findsOneWidget);
        expect(repository.writes, submit ? 1 : 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
