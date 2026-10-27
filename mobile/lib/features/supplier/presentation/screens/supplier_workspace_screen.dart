import '../../../supplies/presentation/widgets/supply_fields_dialog.dart';
import '../../../supplies/presentation/widgets/supply_disputes_panel.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'dart:async';

import '../../../../core/utils/api_error_message.dart';
import '../../../supplies/domain/repositories/supplies_repository.dart';
import '../../../supplies/presentation/providers/supplies_providers.dart';
import '../../../supplies/presentation/widgets/supplies_ui.dart';

final supplierOrdersProvider = FutureProvider.autoDispose<List<SupplyData>>((
  ref,
) {
  final timer = Timer.periodic(const Duration(seconds: 15), (_) {
    if (ref.mounted) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(timer.cancel);
  return ref.watch(suppliesRepositoryProvider).list('/supplier/orders');
});
final supplierProductsProvider = FutureProvider.autoDispose
    .family<List<SupplyData>, String>(
      (ref, id) => ref
          .watch(suppliesRepositoryProvider)
          .list('/suppliers/$id/products?includeInactive=true'),
    );

class SupplierWorkspaceScreen extends ConsumerStatefulWidget {
  const SupplierWorkspaceScreen({super.key});
  @override
  ConsumerState<SupplierWorkspaceScreen> createState() =>
      _SupplierWorkspaceScreenState();
}

class _SupplierWorkspaceScreenState
    extends ConsumerState<SupplierWorkspaceScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
      if (mounted) {
        ref.invalidate(supplierProfileProvider);
        ref.invalidate(supplierOrdersProvider);
        ref.invalidate(suppliersProvider);
        ref.invalidate(supplierProductsProvider);
        ref.invalidate(supplyProductsProvider);
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<SupplyData?> _edit(
    String title,
    Map<String, String> fields, {
    Map<String, String> initial = const {},
  }) async {
    return showDialog<SupplyData>(
      context: context,
      builder: (_) =>
          SupplyFieldsDialog(title: title, fields: fields, initial: initial),
    );
  }

  Future<void> _profile(SupplyData? s) async {
    final r = await _edit(
      'Supplier profile',
      {
        'name': 'Supplier name',
        'phone': 'Public phone',
        'email': 'Public email',
        'deliveryArea': 'Delivery area',
        'deliveryFee': 'Delivery fee (VND)',
      },
      initial: {
        for (final k in [
          'name',
          'phone',
          'email',
          'deliveryArea',
          'deliveryFee',
        ])
          k: s?[k]?.toString() ?? '',
      },
    );
    if (r == null || !mounted) return;
    await _run(() async {
      await ref.read(suppliesRepositoryProvider).mutate('/supplier/profile', {
        ...r,
        'deliveryFee': num.tryParse(r['deliveryFee'].toString()) ?? 0,
      }, method: 'PUT');
    });
  }

  Future<void> _product([SupplyData? p]) async {
    final r = await _edit(
      p == null ? 'Add product' : 'Edit product',
      {
        'sku': 'SKU',
        'name': 'Product name',
        'unit': 'Unit / package size',
        'price': 'Price (VND)',
        'availableQuantity': 'Available stock',
      },
      initial: {
        for (final k in ['sku', 'name', 'unit', 'price', 'availableQuantity'])
          k: p?[k]?.toString() ?? '',
      },
    );
    if (r == null || !mounted) return;
    await _run(() async {
      await ref.read(suppliesRepositoryProvider).mutate(
        p == null ? '/supplier/products' : '/supplier/products/${p['id']}',
        {
          ...r,
          'price': num.tryParse(r['price'].toString()) ?? 0,
          'availableQuantity':
              int.tryParse(r['availableQuantity'].toString()) ?? -1,
          'active': p?['active'] != false,
          if (p != null) 'expectedVersion': p['version'],
        },
        method: p == null ? 'POST' : 'PUT',
      );
    });
  }

  Future<void> _refund(SupplyData o) async {
    final r = await _edit('Report supplier refund', {
      'amount': 'Amount returned (VND)',
      'reference': 'Bank reference',
      'reason': 'Reason',
    });
    if (r == null || !mounted) return;
    await _run(() async {
      await ref.read(suppliesRepositoryProvider).mutate(
        '/supplier/orders/${o['id']}/refunds',
        {
          ...r,
          'clientRequestId': const Uuid().v4(),
          'amount': num.tryParse(r['amount'].toString()) ?? 0,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) => SuppliesPage(
    title: 'Supplier workspace',
    child: ref
        .watch(supplierProfileProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              SupplyFailure(e, () => ref.invalidate(supplierProfileProvider)),
          data: (profile) {
            final s = profile['supplier'] is Map
                ? Map<String, dynamic>.from(profile['supplier'] as Map)
                : null;
            if (profile['canOperate'] != true && s == null) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Supplier access has not been assigned to this account.',
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SupplySurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s?['name']?.toString() ??
                            'Set up your supplier profile',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (s != null)
                        Text(
                          '${s['phone']}\n${s['email']}\n${s['deliveryArea']}',
                        ),
                      TextButton(
                        onPressed: _busy ? null : () => _profile(s),
                        child: const Text('Edit supplier profile'),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_busy) const LinearProgressIndicator(),
                if (s != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Products',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _product,
                        child: const Text('Add product'),
                      ),
                    ],
                  ),
                  ref
                      .watch(supplierProductsProvider(s['id'].toString()))
                      .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => SupplyFailure(
                          e,
                          () => ref.invalidate(supplierProductsProvider),
                        ),
                        data: (items) => Column(
                          children: [
                            if (items.isEmpty) const Text('No products yet.'),
                            for (final p in items)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(p['name'].toString()),
                                subtitle: Text(
                                  '${supplyMoney(p['price'])} / ${p['unit']} · stock ${p['availableQuantity']}',
                                ),
                                trailing: IconButton(
                                  tooltip: 'Edit product',
                                  onPressed: _busy ? null : () => _product(p),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 24),
                  Text(
                    'Paid orders',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ref
                      .watch(supplierOrdersProvider)
                      .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => SupplyFailure(
                          e,
                          () => ref.invalidate(supplierOrdersProvider),
                        ),
                        data: (orders) => Column(
                          children: [
                            if (orders.isEmpty)
                              const Text('No paid orders yet.'),
                            for (final o in orders)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: SupplySurface(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${supplyMoney(o['total'])} · ${o['status']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        '${o['deliveryAddress']}\n${o['contactPhone']}',
                                      ),
                                      for (final line in o['lines'] as List)
                                        Text(
                                          '${line['quantity']} × ${line['name']}',
                                        ),
                                      if (o['status'] == 'PAID' ||
                                          o['status'] == 'FULFILLING')
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _run(() async {
                                                  final next =
                                                      o['status'] == 'PAID'
                                                      ? 'FULFILLING'
                                                      : 'DELIVERED';
                                                  await ref
                                                      .read(
                                                        suppliesRepositoryProvider,
                                                      )
                                                      .mutate(
                                                        '/supplier/orders/${o['id']}/fulfillment?status=$next',
                                                        {
                                                          'expectedVersion':
                                                              o['version'],
                                                        },
                                                      );
                                                }),
                                          child: Text(
                                            o['status'] == 'PAID'
                                                ? 'Start preparing'
                                                : 'Mark delivered',
                                          ),
                                        ),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _refund(o),
                                        child: const Text(
                                          'Report money refunded to payer',
                                        ),
                                      ),
                                      SupplyDisputesPanel(
                                        orderId: o['id'].toString(),
                                        supplier: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                ],
              ],
            );
          },
        ),
  );
}
