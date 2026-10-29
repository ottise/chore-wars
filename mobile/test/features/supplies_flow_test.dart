import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/supplies/domain/repositories/supplies_repository.dart';
import 'package:chore_wars/features/supplies/presentation/providers/supplies_providers.dart';
import 'package:chore_wars/features/supplies/presentation/screens/supplies_catalog_screen.dart';
import 'package:chore_wars/features/supplies/presentation/screens/household_debts_screen.dart';
import 'package:chore_wars/features/supplies/presentation/widgets/ai_supply_draft_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/supply_capture.dart';

class _Shop extends Fake implements SuppliesRepository {
  final requests = <SupplyData>[];
  static const supplier = {
    'id': 'shop',
    'name': 'Test supplier',
    'phone': '',
    'email': 'shop@example.test',
    'deliveryArea': 'Test area',
    'deliveryFee': 0,
  };
  static const product = {
    'id': 'rice',
    'supplierId': 'shop',
    'name': 'Rice',
    'unit': '10 kg bag',
    'price': 240000,
    'availableQuantity': 3,
  };
  @override
  Future<List<SupplyData>> suppliers() async => [supplier];
  @override
  Future<List<SupplyData>> list(String path) async {
    expect(path, '/houses/house/shop/suppliers');
    return [supplier];
  }

  @override
  Future<List<SupplyData>> products(String supplier) async => [product];
  @override
  Future<SupplyData> mutate(
    String path,
    SupplyData request, {
    String method = 'POST',
  }) async {
    requests.add(request);
    expect(path, '/houses/house/orders/send');
    return {'id': 'saved'};
  }

  @override
  Future<List<SupplyData>> orders(String house) async => [];
}

void main() {
  Future<void> setup(WidgetTester tester, _Shop shop, {bool ai = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await loadSupplyCaptureFonts(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: ai ? '/ai' : '/houses/house/orders',
      routes: [
        GoRoute(
          path: '/ai',
          builder: (_, _) => const Scaffold(
            body: AiSupplyDraftCard(
              houseId: 'house',
              candidate: {
                'supplier_id': 'shop',
                'payer_id': 'A',
                'participant_ids': ['A', 'B'],
                'lines': [
                  {'product_id': 'rice', 'quantity': 1},
                ],
              },
            ),
          ),
        ),
        GoRoute(
          path: '/houses/house/orders',
          builder: (_, state) => SuppliesCatalogScreen(
            houseId: 'house',
            aiDraft: state.extra is Map
                ? Map<String, dynamic>.from(state.extra as Map)
                : null,
          ),
        ),
        GoRoute(
          path: '/houses/house/orders/saved',
          builder: (_, _) => const Scaffold(body: Text('Saved order log')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          suppliesRepositoryProvider.overrideWithValue(shop),
          userProfileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'A',
              displayName: 'Alice',
              email: 'a@test.example',
            ),
          ),
          houseMembersProvider.overrideWith(
            (ref, id) async => const [
              HouseMember(
                id: 'ma',
                userId: 'A',
                displayName: 'Alice',
                role: HouseRole.owner,
                status: HouseMemberStatus.active,
              ),
              HouseMember(
                id: 'mb',
                userId: 'B',
                displayName: 'Bob',
                role: HouseRole.member,
                status: HouseMemberStatus.active,
              ),
            ],
          ),
        ],
        child: RepaintBoundary(
          key: supplyCaptureKey,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final ai in [false, true]) {
    testWidgets(
      '${ai ? 'AI' : 'Manual'} selection sends an email order without choosing payer or participants',
      (tester) async {
        final shop = _Shop();
        await setup(tester, shop, ai: ai);
        if (ai) {
          await tester.tap(find.text('Review AI selection'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Contact number not available'), findsOneWidget);
        await captureSupplyScreen(tester, ai ? 'ai-catalog' : 'manual-catalog');
        if (!ai) {
          await tester.ensureVisible(find.byTooltip('Add one Rice'));
          await tester.tap(find.byTooltip('Add one Rice'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Send order'));
        await tester.tap(find.text('Send order'));
        await tester.pumpAndSettle();
        expect(find.text('Saved order log'), findsOneWidget);
        final request = shop.requests.single;
        expect(request.containsKey('payerUserId'), isFalse);
        expect(request.containsKey('shares'), isFalse);
        expect(request['viaAI'], ai);
        expect((request['lines'] as List).single, {
          'productId': 'rice',
          'quantity': 1,
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'direct debts keep opposite directions and show individual remaining amounts',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) async => const UserProfile(
                id: 'A',
                email: 'a@test.example',
                displayName: 'Alice',
              ),
            ),
            purchaseDebtsProvider.overrideWith(
              (ref, house) async => {
                'owe': 50,
                'owedToMe': 120,
                'debts': [
                  {
                    'id': 'ab',
                    'debtorUserId': 'A',
                    'creditorUserId': 'B',
                    'debtorName': 'Alice',
                    'creditorName': 'Bob',
                    'remainingAmount': 50,
                    'status': 'PENDING',
                  },
                  {
                    'id': 'ba',
                    'debtorUserId': 'B',
                    'creditorUserId': 'A',
                    'debtorName': 'Bob',
                    'creditorName': 'Alice',
                    'remainingAmount': 120,
                    'status': 'PENDING',
                  },
                ],
              },
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HouseholdDebtsScreen(houseId: 'house'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Pay Bob'), findsOneWidget);
      expect(find.text('Bob owes you'), findsOneWidget);
      expect(find.text('50 VND remaining · Debt · Pending'), findsOneWidget);
      expect(find.text('120 VND remaining · Debt · Pending'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
