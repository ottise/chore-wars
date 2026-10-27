import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import '../widgets/supplier_contact_card.dart';
import '../widgets/supplies_ui.dart';

class SuppliesCatalogScreen extends ConsumerStatefulWidget {
  const SuppliesCatalogScreen({required this.houseId, this.aiDraft, super.key});
  final String houseId;
  final SupplyData? aiDraft;
  @override
  ConsumerState<SuppliesCatalogScreen> createState() =>
      _SuppliesCatalogScreenState();
}

class _SuppliesCatalogScreenState extends ConsumerState<SuppliesCatalogScreen> {
  String? _supplier;
  final _quantities = <String, int>{};
  @override
  void initState() {
    super.initState();
    _supplier = widget.aiDraft?['supplier_id']?.toString();
    for (final line in widget.aiDraft?['lines'] as List? ?? []) {
      if (line is Map && line['product_id'] != null) {
        _quantities[line['product_id'].toString()] =
            (line['quantity'] as num?)?.toInt() ?? 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    return SuppliesPage(
      title: 'Household Supplies',
      actions: [
        IconButton(
          tooltip: 'Order history',
          onPressed: () =>
              context.push('/houses/${widget.houseId}/supplies/history'),
          icon: const Icon(Icons.history_outlined),
        ),
      ],
      child: suppliers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            SupplyFailure(e, () => ref.invalidate(suppliersProvider)),
        data: (shops) {
          if (shops.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No supplier is available yet.'),
            );
          }
          final supplier = shops.firstWhere(
            (s) => s['id'] == _supplier,
            orElse: () => shops.first,
          );
          final id = supplier['id'].toString();
          return ref
              .watch(supplyProductsProvider(id))
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => SupplyFailure(
                  e,
                  () => ref.invalidate(supplyProductsProvider(id)),
                ),
                data: (products) {
                  final selected = products
                      .where((p) => (_quantities[p['id']] ?? 0) > 0)
                      .toList();
                  final total =
                      selected.fold<num>(
                        0,
                        (sum, p) =>
                            sum + (p['price'] as num) * _quantities[p['id']]!,
                      ) +
                      (supplier['deliveryFee'] as num? ?? 0);
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      SupplierContactCard(supplier: supplier),
                      const SizedBox(height: 24),
                      if (shops.length > 1)
                        DropdownButtonFormField<String>(
                          initialValue: id,
                          decoration: const InputDecoration(
                            labelText: 'Supplier',
                          ),
                          items: shops
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s['id'].toString(),
                                  child: Text(s['name'].toString()),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _supplier = v;
                            _quantities.clear();
                          }),
                        ),
                      if (widget.aiDraft != null &&
                          widget.aiDraft!['revise_order_id'] == null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'AI prepared this selection. Check the available quantities and current prices before continuing.',
                          ),
                        ),
                      if (products.isEmpty)
                        const Text('No products available yet.'),
                      for (final p in products)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SupplySurface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'].toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  '${supplyMoney(p['price'])} / ${p['unit']}',
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${p['availableQuantity']} available',
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove one ${p['name']}',
                                      onPressed:
                                          (_quantities[p['id']] ?? 0) == 0
                                          ? null
                                          : () => setState(
                                              () => _quantities[p['id']] =
                                                  _quantities[p['id']]! - 1,
                                            ),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    Text('${_quantities[p['id']] ?? 0}'),
                                    IconButton(
                                      tooltip: 'Add one ${p['name']}',
                                      onPressed:
                                          (_quantities[p['id']] ?? 0) >=
                                              (p['availableQuantity'] as num)
                                          ? null
                                          : () => setState(
                                              () => _quantities[p['id']] =
                                                  (_quantities[p['id']] ?? 0) +
                                                  1,
                                            ),
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text('Delivery: ${supplyMoney(supplier['deliveryFee'])}'),
                      Text(
                        'Total: ${supplyMoney(total)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => context.push(
                                '/houses/${widget.houseId}/supplies/review',
                                extra: {
                                  'supplier': supplier,
                                  'products': selected,
                                  'quantities': Map<String, int>.from(
                                    _quantities,
                                  ),
                                  'aiDraft': widget.aiDraft,
                                },
                              ),
                        child: const Text('Review purchase'),
                      ),
                      TextButton(
                        onPressed: () => context.push(
                          '/houses/${widget.houseId}/supplies/schedules',
                        ),
                        child: const Text('Purchase reminders'),
                      ),
                    ],
                  );
                },
              );
        },
      ),
    );
  }
}
