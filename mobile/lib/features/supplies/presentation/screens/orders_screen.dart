import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import '../widgets/supplier_contact_card.dart';
import '../widgets/supplies_ui.dart';
import '../widgets/shop_item_dialog.dart';
import '../widgets/shop_presets.dart';

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
  final Set<String> _shareUserIds = {};
  bool _sharesInitialized = false;

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

  Future<void> _send(
    SupplyData supplier,
    List<SupplyData> selected, {
    bool payNow = false,
  }) async {
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
          'shares': _shareUserIds.map((userId) => {'userId': userId}).toList(),
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
        if (!mounted) return;
        final path = '/houses/${widget.houseId}/orders/${order['id']}';
        if (payNow) {
          context.push('$path?payNow=1');
        } else {
          await supplyOpenOrderSms(context, order);
          if (mounted) context.push(path);
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _addItem([ShopPreset? preset]) async {
    final supplierId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShopItemDialog(houseId: widget.houseId, preset: preset),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF7C4DFF),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Shop'),
                  Tab(text: 'Orders'),
                ],
              ),
            ),
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
          final members =
              ref.watch(houseMembersProvider(widget.houseId)).asData?.value ??
              const [];
          final me = ref.watch(userProfileProvider).asData?.value.id;
          if (!_sharesInitialized && members.isNotEmpty && me != null) {
            _sharesInitialized = true;
            _shareUserIds
              ..clear()
              ..addAll(members.map((member) => member.userId));
            _shareUserIds.add(me);
          }
          if (shops.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SupplySurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No supplier contacts yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Add a supplier item and contact details to get started.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ShopPresets(onSelect: (p) => _addItem(p)),
              ],
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
                    cacheExtent: 0,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
                    children: [
                      ShopPresets(
                        onSelect: _sending ? null : (p) => _addItem(p),
                      ),
                      const SizedBox(height: 14),
                      if (shops.length > 1) ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
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
                        const SizedBox(height: 12),
                      ],
                      SupplierContactCard(supplier: supplier),
                      const SizedBox(height: 16),
                      const Text(
                        'Supplier items',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (products.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No items are available yet.'),
                        ),
                      for (final p in products)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ProductTile(
                            product: p,
                            quantity: _quantities[p['id']] ?? 0,
                            sending: _sending,
                            onDecrement: (_quantities[p['id']] ?? 0) == 0
                                ? null
                                : () => setState(() {
                                    _quantities[p['id']] =
                                        _quantities[p['id']]! - 1;
                                    _requestId = const Uuid().v4();
                                  }),
                            onIncrement:
                                (_quantities[p['id']] ?? 0) >= 1000 ||
                                    (_quantities[p['id']] ?? 0) >=
                                        (p['availableQuantity'] as num? ?? 0)
                                ? null
                                : () => setState(() {
                                    _quantities[p['id']] =
                                        (_quantities[p['id']] ?? 0) + 1;
                                    _requestId = const Uuid().v4();
                                  }),
                          ),
                        ),
                      if (selected.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SupplySurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery: ${supplyMoney(supplier['deliveryFee'])}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total: ${supplyMoney(total)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF7C4DFF),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _note,
                                enabled: !_sending,
                                maxLength: 1000,
                                onChanged: (_) =>
                                    _requestId = const Uuid().v4(),
                                decoration: const InputDecoration(
                                  labelText: 'Note (optional)',
                                  counterText: '',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Split this order',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Selected members share the total equally. Debts are recorded only after PayOS verifies payment.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final member in members)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value:
                                _shareUserIds.contains(member.userId) ||
                                member.userId == me,
                            title: Text(
                              member.userId == me
                                  ? '${member.displayName} (payer)'
                                  : member.displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: _sending || member.userId == me
                                ? null
                                : (checked) => setState(() {
                                    if (checked == true) {
                                      _shareUserIds.add(member.userId);
                                    } else {
                                      _shareUserIds.remove(member.userId);
                                    }
                                  }),
                          ),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
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
                                  (supplier['phone']
                                          ?.toString()
                                          .trim()
                                          .isEmpty ??
                                      true)
                              ? null
                              : () => _send(supplier, selected),
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: Text(
                            _sending ? 'Saving order…' : 'Save & open SMS',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _send(supplier, selected, payNow: true),
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('Save & pay with PayOS'),
                        ),
                        if (supplier['phone']?.toString().trim().isEmpty ??
                            true)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Add a supplier phone number to prepare an SMS order.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              );
        },
      );
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.quantity,
    required this.sending,
    required this.onDecrement,
    required this.onIncrement,
  });

  final SupplyData product;
  final int quantity;
  final bool sending;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final active = quantity > 0;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: active ? const Color(0xFFC4B5FD) : const Color(0xFFE8ECF2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFEDE7FF)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: active
                    ? const Color(0xFF7C4DFF)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${supplyMoney(product['price'])} / ${product['unit']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Remove one ${product['name']}',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: sending ? null : onDecrement,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '$quantity',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? const Color(0xFF7C4DFF)
                            : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add one ${product['name']}',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: sending ? null : onIncrement,
                    icon: const Icon(Icons.add_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (orders.isEmpty)
                const SupplySurface(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 36,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No orders yet.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final order in orders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OrderHistoryCard(
                    order: order,
                    onTap: () =>
                        context.push('/houses/$houseId/orders/${order['id']}'),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({required this.order, required this.onTap});

  final SupplyData order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paid =
        order['paymentConfirmationSource'] != null || order['status'] == 'PAID';
    final statusLabel = switch (order['workflow']) {
      'SIMPLE_SMS' => paid ? 'Payment recorded' : 'Order saved',
      'SIMPLE_CONTACT' =>
        paid
            ? 'Payment recorded'
            : switch (order['emailStatus']) {
                'SENT' => 'Email sent',
                'UNKNOWN' => 'Email result unknown',
                'FAILED' => 'Email failed',
                _ => 'Sending email…',
              },
      _ => order['status']?.toString().replaceAll('_', ' ') ?? 'Draft',
    };
    final shortId = order['id'].toString().split('-').first;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE8ECF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: paid
                      ? const Color(0xFFE6F7F0)
                      : const Color(0xFFEDE7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  paid
                      ? Icons.check_circle_outline_rounded
                      : Icons.receipt_long_rounded,
                  size: 20,
                  color: paid
                      ? const Color(0xFF0D9F6E)
                      : const Color(0xFF7C4DFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['supplierName']?.toString().isNotEmpty == true
                          ? order['supplierName'].toString()
                          : 'Order #$shortId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${supplyMoney(order['total'])} · $statusLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
