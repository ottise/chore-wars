import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/session_provider.dart';
import '../../data/datasources/supplies_remote_data_source.dart';
import '../../data/repositories/supplies_repository_impl.dart';
import '../../domain/repositories/supplies_repository.dart';

final suppliesRepositoryProvider = Provider<SuppliesRepository>((ref) {
  ref.watch(sessionEpochProvider);
  return SuppliesRepositoryImpl(
    SuppliesRemoteDataSource(ref.watch(dioProvider)),
  );
});
final suppliersProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(suppliesRepositoryProvider).suppliers(),
);
final houseShopSuppliersProvider = FutureProvider.autoDispose
    .family<List<SupplyData>, String>(
      (ref, house) => ref
          .watch(suppliesRepositoryProvider)
          .list('/houses/$house/shop/suppliers'),
    );
final supplyProductsProvider = FutureProvider.autoDispose
    .family<List<SupplyData>, String>(
      (ref, supplier) =>
          ref.watch(suppliesRepositoryProvider).products(supplier),
    );
final supplyOrdersProvider = FutureProvider.autoDispose
    .family<List<SupplyData>, String>(
      (ref, house) => ref.watch(suppliesRepositoryProvider).orders(house),
    );
final supplyOrderProvider = FutureProvider.autoDispose
    .family<SupplyData, ({String house, String id})>((ref, key) {
      final timer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (ref.mounted) ref.invalidateSelf();
      });
      ref.onDispose(timer.cancel);
      return ref.watch(suppliesRepositoryProvider).order(key.house, key.id);
    });
final purchaseDebtsProvider = FutureProvider.autoDispose
    .family<SupplyData, String>(
      (ref, house) => ref.watch(suppliesRepositoryProvider).debts(house),
    );
final supplySchedulesProvider = FutureProvider.autoDispose
    .family<List<SupplyData>, String>(
      (ref, house) => ref
          .watch(suppliesRepositoryProvider)
          .list('/houses/$house/supply-schedules'),
    );
final supplierProfileProvider = FutureProvider.autoDispose<SupplyData>(
  (ref) => ref.watch(suppliesRepositoryProvider).get('/supplier/profile'),
);
final ownBankProvider = FutureProvider.autoDispose<SupplyData>(
  (ref) => ref.watch(suppliesRepositoryProvider).get('/user/bank-account'),
);
