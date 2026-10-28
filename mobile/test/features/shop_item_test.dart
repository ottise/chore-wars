import 'package:chore_wars/features/supplies/domain/repositories/supplies_repository.dart';
import 'package:chore_wars/features/supplies/presentation/providers/supplies_providers.dart';
import 'package:chore_wars/features/supplies/presentation/widgets/shop_item_dialog.dart';
import 'package:chore_wars/features/supplies/presentation/widgets/supplier_contact_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Shop extends SuppliesRepository {
  final requests = <SupplyData>[];
  bool fail = true;
  @override
  Future<SupplyData> mutate(
    String path,
    SupplyData request, {
    String method = 'POST',
  }) async {
    expect(path, '/houses/home/shop/items');
    requests.add(Map.of(request));
    if (fail) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
      );
    }
    return {
      'supplier': {'id': 'contact'},
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('contact actions match available details', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SupplierContactCard(
            supplier: {
              'name': 'Rice shop',
              'phone': '0901234567',
              'email': 'shop@example.test',
            },
          ),
        ),
      ),
    );
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Copy number'), findsOneWidget);
    expect(find.text('shop@example.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'save validates contact and keeps the same request and text after a network failure',
    (tester) async {
      final repo = _Shop();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [suppliesRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ShopItemDialog(houseId: 'home'),
                  ),
                  child: const Text('Add item'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();
      expect(repo.requests, isEmpty);
      final values = [
        'ST25 rice',
        '5 kg bag',
        '150000',
        'Rice shop',
        '0901234567',
        'shop@example.test',
      ];
      for (var i = 0; i < values.length; i++) {
        await tester.ensureVisible(find.byType(TextFormField).at(i));
        await tester.enterText(find.byType(TextFormField).at(i), values[i]);
      }
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();
      expect(repo.requests.length, 1);
      expect(find.text('ST25 rice'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();
      expect(repo.requests.length, 2);
      expect(
        repo.requests[0]['clientRequestId'],
        repo.requests[1]['clientRequestId'],
      );
      expect(find.text('Save item'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
