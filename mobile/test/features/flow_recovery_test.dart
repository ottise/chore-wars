import 'dart:typed_data';
import 'dart:async';

import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/core/storage/session_provider.dart';
import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/chat/providers/voice_note_provider.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/house/presentation/screens/my_houses_screen.dart';
import 'package:chore_wars/features/supplies/domain/repositories/supplies_repository.dart';
import 'package:chore_wars/features/supplies/presentation/providers/supplies_providers.dart';
import 'package:chore_wars/features/supplies/presentation/widgets/shop_item_dialog.dart';
import 'package:chore_wars/features/supplies/presentation/widgets/shop_presets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MissingMedia implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}

class _Shop extends Fake implements SuppliesRepository {
  SupplyData? saved;
  @override
  Future<SupplyData> mutate(
    String path,
    SupplyData request, {
    String method = 'POST',
  }) async {
    expect(path, '/houses/home/shop/items');
    saved = request;
    return {
      'supplier': {'id': 'contact'},
    };
  }
}

class _SlowOrder extends Fake implements SuppliesRepository {
  int calls = 0;
  final response = Completer<SupplyData>();
  @override
  Future<SupplyData> order(String house, String id) {
    calls++;
    return response.future;
  }
}

void main() {
  testWidgets(
    'order polling does not restart a slow request and polls unpaid SMS orders',
    (tester) async {
      final shop = _SlowOrder();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [suppliesRepositoryProvider.overrideWithValue(shop)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) => Text(
                ref
                        .watch(
                          supplyOrderProvider((house: 'home', id: 'order')),
                        )
                        .hasValue
                    ? 'Saved'
                    : 'Loading',
              ),
            ),
          ),
        ),
      );
      expect(shop.calls, 1);
      await tester.pump(const Duration(seconds: 20));
      expect(shop.calls, 1);
      shop.response.complete({'workflow': 'SIMPLE_SMS'});
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(shop.calls, 2);
      expect(find.text('Saved'), findsOneWidget);
    },
  );
  test(
    'missing private media stops retrying and account switches invalidate it',
    () async {
      final adapter = _MissingMedia();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      addTearDown(dio.close);
      final provider = privateMediaProvider('missing');
      final listen = container.listen(provider, (_, _) {});
      addTearDown(listen.close);
      await expectLater(
        container.read(provider.future),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await expectLater(
        container.read(provider.future),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 1);
      container.read(sessionEpochProvider.notifier).advance();
      await expectLater(
        container.read(provider.future),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 2);
    },
  );
  for (final width in [320.0, 354.0, 480.0]) {
    testWidgets('My Houses header fits $width and an increased text scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myHousesProvider.overrideWith((ref) async => [])],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const MyHousesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Profile'), findsOneWidget);
      expect(find.byTooltip('Scan QR to join'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'preset prices remain editable and only a phone is needed to finish a preset',
    (tester) async {
      final shop = _Shop();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [suppliesRepositoryProvider.overrideWithValue(shop)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Rice'),
                  onPressed: () => showDialog<String>(
                    context: context,
                    builder: (_) =>
                        ShopItemDialog(houseId: 'home', preset: shopPresets[1]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Rice'));
      await tester.pumpAndSettle();
      expect(find.text('160000'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(2), '180000');
      await tester.ensureVisible(find.byType(TextFormField).at(4));
      await tester.enterText(find.byType(TextFormField).at(4), '0901234567');
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();
      expect(shop.saved?['price'], 180000);
      expect(shop.saved?['phone'], '0901234567');
      expect(shop.saved?['name'], 'Rice');
      expect(tester.takeException(), isNull);
    },
  );
}
