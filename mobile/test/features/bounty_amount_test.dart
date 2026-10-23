import 'package:chore_wars/features/bounty/domain/entities/bounty.dart';
import 'package:chore_wars/features/bounty/domain/repositories/bounty_repository.dart';
import 'package:chore_wars/features/bounty/presentation/providers/bounty_providers.dart';
import 'package:chore_wars/features/bounty/presentation/screens/create_bounty_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends Fake implements BountyRepository {
  final amounts = <double>[];
  @override
  Future<Bounty> createBounty({
    required String houseId,
    required String choreOccurrenceId,
    required double amount,
  }) async {
    amounts.add(amount);
    throw StateError('Stop after recording the request');
  }
}

void main() {
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
