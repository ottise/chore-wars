import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/supplies/domain/repositories/supplies_repository.dart';
import 'package:chore_wars/features/supplies/presentation/providers/supplies_providers.dart';
import 'package:chore_wars/features/supplies/presentation/screens/household_debts_screen.dart';
import 'package:chore_wars/features/house/presentation/providers/household_summary_provider.dart';
import 'package:chore_wars/features/house/presentation/widgets/household_summary_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Finance extends Fake implements SuppliesRepository {
  final calls = <(String, SupplyData)>[];
  final bool pendingReceipt;
  _Finance({this.pendingReceipt = false});
  @override
  Future<List<SupplyData>> list(String path) async => [];
  @override
  Future<SupplyData> debts(String house) async => {
    'owe': 100,
    'owedToMe': 100,
    'debts': [
      {
        'id': 'out',
        'debtorUserId': 'A',
        'creditorUserId': 'B',
        'debtorName': 'Alice',
        'creditorName': 'Bob',
        'remainingAmount': 100,
        'status': 'PENDING',
        'reason': 'BOUNTY_PAYMENT',
        'repayments': [
          {'id': 'pending-out', 'amount': 40, 'status': 'REPORTED'},
        ],
      },
      {
        'id': 'in',
        'debtorUserId': 'B',
        'creditorUserId': 'A',
        'debtorName': 'Bob',
        'creditorName': 'Alice',
        'remainingAmount': 100,
        'status': 'PENDING',
        'reason': 'OTHER',
        'repayments': pendingReceipt
            ? [
                {'id': 'pending-in', 'amount': 100, 'status': 'REPORTED'},
              ]
            : [],
      },
      {
        'id': 'settled',
        'debtorUserId': 'B',
        'creditorUserId': 'A',
        'debtorName': 'Settled member',
        'creditorName': 'Alice',
        'remainingAmount': 0,
        'status': 'PAID',
        'repayments': [],
      },
    ],
  };
  @override
  Future<SupplyData> mutate(
    String path,
    SupplyData body, {
    String method = 'POST',
  }) async {
    calls.add((path, body));
    return {};
  }
}

Future<void> _mount(WidgetTester tester, _Finance repo) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        suppliesRepositoryProvider.overrideWithValue(repo),
        userProfileProvider.overrideWith(
          (ref) async => const UserProfile(
            id: 'A',
            displayName: 'Alice',
            email: 'a@example.test',
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HouseholdDebtsScreen(houseId: 'house'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'debtor reports only the amount not already awaiting confirmation',
    (tester) async {
      final repo = _Finance();
      await _mount(tester, repo);
      expect(find.textContaining('Settled member'), findsNothing);
      await tester.ensureVisible(find.text('Mark as paid'));
      await tester.tap(find.text('Mark as paid'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '60',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Mark as paid'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid'));
      await tester.pumpAndSettle();
      expect(repo.calls.single.$1, '/payment-obligations/out/repayments');
      expect(repo.calls.single.$2['amount'], 60);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('creditor records actual receipt using a separate operation', (
    tester,
  ) async {
    final repo = _Finance();
    await _mount(tester, repo);
    await tester.ensureVisible(find.text('Confirm received'));
    await tester.tap(find.text('Confirm received'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    await tester.ensureVisible(find.text('Record receipt'));
    await tester.tap(find.text('Record receipt'));
    await tester.pumpAndSettle();
    expect(repo.calls.single.$1, '/payment-obligations/in/record-receipt');
    expect(repo.calls.single.$2['amount'], 100);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'creditor reviews a pending report instead of creating another receipt',
    (tester) async {
      final repo = _Finance(pendingReceipt: true);
      await _mount(tester, repo);
      await tester.ensureVisible(find.text('Confirm received'));
      await tester.tap(find.text('Confirm received'));
      await tester.pumpAndSettle();
      expect(find.text('Record receipt'), findsNothing);
      await tester.tap(find.text('Not received'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      await tester.enterText(find.byType(TextField).last, 'Not in my account');
      await tester.tap(find.text('Not received'));
      await tester.pumpAndSettle();
      expect(
        repo.calls.single.$1,
        '/payment-obligations/in/repayments/pending-in/respond',
      );
      expect(repo.calls.single.$2['confirm'], false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'household summary uses real counts and keeps internal transfers separate',
    (tester) async {
      tester.view.physicalSize = const Size(354, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final summary = {
        'externalPayments': 300000,
        'internalTransfers': 100000,
        'paidOrderCount': 1,
        'unpaidOrderCount': 0,
        'assigned': 0,
        'completed': 0,
        'onTime': 0,
        'overdue': 0,
        'upcoming': 0,
        'skipped': 0,
        'orders': [],
        'members': [],
      };
      for (final section in [1, 2, 3]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              householdSummaryProvider.overrideWith((ref, q) async => summary),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: HouseholdSummarySection(
                  key: ValueKey(section),
                  houseId: 'h',
                  seasonId: 's',
                  section: section,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (section == 1) {
          expect(find.text('300,000 VND'), findsOneWidget);
          expect(find.text('100,000 VND'), findsOneWidget);
        }
        if (section == 2) {
          expect(find.text('No chores yet for this period.'), findsOneWidget);
          expect(find.text('Not available'), findsOneWidget);
        }
        if (section == 3) {
          expect(find.text('No member data yet.'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
