import 'package:go_router/go_router.dart';
import 'package:chore_wars/features/bounty/domain/entities/bounty.dart';
import 'package:chore_wars/features/bounty/domain/repositories/bounty_repository.dart';
import 'package:chore_wars/features/bounty/presentation/providers/bounty_providers.dart';
import 'package:chore_wars/features/bounty/presentation/screens/create_bounty_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends Fake implements BountyRepository {
  final amounts = <double>[];
  bool succeed = false;
  @override
  Future<Bounty> createBounty({
    required String houseId,
    required String choreOccurrenceId,
    required double amount,
  }) async {
    amounts.add(amount);
    if (succeed) {
      return Bounty(
        id: 'saved',
        choreOccurrenceId: choreOccurrenceId,
        choreName: 'Chore',
        postedByUserId: 'me',
        postedByDisplayName: 'Me',
        amount: amount,
        status: BountyStatus.open,
        expiresAt: DateTime.utc(2030),
      );
    }
    throw StateError('Stop after recording the request');
  }
}

void main() {
  for (final submit in [false, true]) {
    testWidgets(
      'direct bounty create ${submit ? 'successful post' : 'Back'} returns safely to the board',
      (tester) async {
        final repository = _Repository()..succeed = true;
        final router = GoRouter(
          initialLocation: '/create',
          routes: [
            GoRoute(
              path: '/create',
              builder: (_, _) => const CreateBountyScreen(
                houseId: 'h',
                occurrenceId: 'o',
                choreName: 'Chore',
                deadline: null,
              ),
            ),
            GoRoute(
              path: '/houses/h/bounties',
              builder: (_, _) => const Scaffold(body: Text('Bounty board')),
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
          await tester.enterText(find.byType(TextFormField), '500');
          await tester.tap(find.text('POST BOUNTY'));
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();
        expect(find.text('Bounty board'), findsOneWidget);
        expect(repository.amounts, submit ? [500.0] : []);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('English bounty input preserves decimals and comma grouping', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bountyRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: CreateBountyScreen(
            houseId: 'h',
            occurrenceId: 'o',
            choreName: 'Chore',
            deadline: null,
          ),
        ),
      ),
    );
    for (final input in ['1,000.50', '50,000', 'NaN']) {
      await tester.enterText(find.byType(TextFormField), input);
      await tester.tap(find.text('POST BOUNTY'));
      await tester.pumpAndSettle();
    }
    expect(repository.amounts, [1000.5, 50000]);
    expect(find.text('Enter a valid amount.'), findsOneWidget);
  });
}
