import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import '../widgets/supplier_contact_card.dart';
import '../widgets/supplies_ui.dart';
import '../widgets/shop_item_dialog.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({
    required this.houseId,
    this.aiDraft,
    this.initialTab = 0,
    super.key,
  });
  final String houseId;
  final SupplyData? aiDraft;
  final int initialTab;
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _quantities = <String, int>{};
  final _note = TextEditingController();
  String? _supplier;
  String _requestId = const Uuid().v4();
  bool _sending = false;
  String? _error;
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
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send(SupplyData supplier, List<SupplyData> selected) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final order = await ref.read(suppliesRepositoryProvider).mutate(
        '/houses/${widget.houseId}/orders/send',
        {
          'clientRequestId': _requestId,
          'supplierId': supplier['id'],
          'note': _note.text,
          'viaAI': widget.aiDraft != null,
          'lines': selected
              .map(
                (p) => {'productId': p['id'], 'quantity': _quantities[p['id']]},
              )
              .toList(),
        },
      );
      ref.invalidate(supplyOrdersProvider(widget.houseId));
      if (mounted) {
        setState(() {
          _quantities.clear();
          _note.clear();
          _requestId = const Uuid().v4();
        });
        context.push('/houses/${widget.houseId}/orders/${order['id']}');
        await supplyOpenOrderSms(context, order);
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _addItem() async {
    final supplierId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShopItemDialog(houseId: widget.houseId),
    );
    if (mounted && supplierId != null) {
      setState(() {
        _supplier = supplierId;
        _quantities.clear();
        _requestId = const Uuid().v4();
      });
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: widget.initialTab,
    child: SuppliesPage(
      title: 'Orders',
      actions: [
        IconButton(
          tooltip: 'Add shop item',
          onPressed: _sending ? null : _addItem,
          icon: const Icon(Icons.add),
        ),
      ],
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Shop'),
              Tab(text: 'Orders'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _shop(),
                OrdersHistoryBody(houseId: widget.houseId),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _shop() => ref
      .watch(houseShopSuppliersProvider(widget.houseId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SupplyFailure(
          e,
          () => ref.invalidate(houseShopSuppliersProvider(widget.houseId)),
        ),
        data: (shops) {
          if (shops.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No shop items yet. Add an item and its contact details to get started.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ],
              ),
            );
          }
          final supplier =
              shops.where((s) => s['id'] == _supplier).firstOrNull ??
              shops.first;
          return ref
              .watch(supplyProductsProvider(supplier['id'].toString()))
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => SupplyFailure(
                  e,
                  () => ref.invalidate(
                    supplyProductsProvider(supplier['id'].toString()),
                  ),
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
                    children: [
                      if (shops.length > 1)
                        DropdownButtonFormField<String>(
                          initialValue: supplier['id'].toString(),
                          decoration: const InputDecoration(
                            labelText: 'Supplier',
                          ),
                          items: shops
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s['id'].toString(),
                                  child: Text(
                                    s['name'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _sending
                              ? null
                              : (id) => setState(() {
                                  _supplier = id;
                                  _quantities.clear();
                                  _requestId = const Uuid().v4();
                                }),
                        ),
                      SupplierContactCard(supplier: supplier),
                      const SizedBox(height: 24),
                      if (products.isEmpty)
                        const Text('No items are available yet.'),
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
                                const SizedBox(height: 6),
                                Text(
                                  '${supplyMoney(p['price'])} / ${p['unit']}',
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: 'Remove one ${p['name']}',
                                      onPressed:
                                          _sending ||
                                              (_quantities[p['id']] ?? 0) == 0
                                          ? null
                                          : () => setState(() {
                                              _quantities[p['id']] =
                                                  _quantities[p['id']]! - 1;
                                              _requestId = const Uuid().v4();
                                            }),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    Text('${_quantities[p['id']] ?? 0}'),
                                    IconButton(
                                      tooltip: 'Add one ${p['name']}',
                                      onPressed:
                                          _sending ||
                                              (_quantities[p['id']] ?? 0) >=
                                                  1000 ||
                                              (_quantities[p['id']] ?? 0) >=
                                                  (p['availableQuantity']
                                                          as num? ??
                                                      0)
                                          ? null
                                          : () => setState(() {
                                              _quantities[p['id']] =
                                                  (_quantities[p['id']] ?? 0) +
                                                  1;
                                              _requestId = const Uuid().v4();
                                            }),
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      TextField(
                        controller: _note,
                        enabled: !_sending,
                        maxLength: 1000,
                        onChanged: (_) => _requestId = const Uuid().v4(),
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                        ),
                      ),
                      Text('Delivery: ${supplyMoney(supplier['deliveryFee'])}'),
                      const SizedBox(height: 8),
                      Text(
                        'Total: ${supplyMoney(total)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed:
                            _sending ||
                                selected.isEmpty ||
                                (supplier['phone']?.toString().trim().isEmpty ??
                                    true)
                            ? null
                            : () => _send(supplier, selected),
                        icon: const Icon(Icons.send_outlined),
                        label: Text(
                          _sending ? 'Saving order…' : 'Save & open SMS',
                        ),
                      ),
                      if (supplier['phone']?.toString().trim().isEmpty ?? true)
                        const Text(
                          'Add a supplier phone number to prepare an SMS order.',
                        ),
                    ],
                  );
                },
              );
        },
      );
}

class OrdersHistoryBody extends ConsumerWidget {
  const OrdersHistoryBody({required this.houseId, super.key});
  final String houseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(supplyOrdersProvider(houseId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SupplyFailure(
          e,
          () => ref.invalidate(supplyOrdersProvider(houseId)),
        ),
        data: (orders) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(supplyOrdersProvider(houseId));
            await ref.read(supplyOrdersProvider(houseId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (orders.isEmpty) const Text('No orders yet.'),
              for (final order in orders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SupplySurface(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(order['supplierName'].toString()),
                      subtitle: Text(
                        '${supplyMoney(order['total'])} · ${order['workflow'] == 'SIMPLE_SMS'
                            ? order['paymentConfirmationSource'] != null
                                  ? 'Payment recorded'
                                  : 'Order saved'
                            : order['workflow'] == 'SIMPLE_CONTACT'
                            ? order['paymentConfirmationSource'] != null
                                  ? 'Payment recorded'
                                  : switch (order['emailStatus']) {
                                      'SENT' => 'Email sent',
                                      'UNKNOWN' => 'Email result unknown',
                                      'FAILED' => 'Email failed',
                                      _ => 'Sending email…',
                                    }
                            : order['status']}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/houses/$houseId/orders/${order['id']}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
