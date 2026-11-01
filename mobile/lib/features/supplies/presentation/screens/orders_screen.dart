import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Add shop item',
              padding: EdgeInsets.zero,
              onPressed: _sending ? null : _addItem,
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Container(
              height: 46,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1ECE7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF7C4DFF),
                unselectedLabelColor: const Color(0xFF8C7E74),
                labelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Shop Catalog'),
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

enum OrderFilter { all, unpaid, paid }

class OrdersHistoryBody extends ConsumerStatefulWidget {
  const OrdersHistoryBody({required this.houseId, super.key});
  final String houseId;

  @override
  ConsumerState<OrdersHistoryBody> createState() => _OrdersHistoryBodyState();
}

class _OrdersHistoryBodyState extends ConsumerState<OrdersHistoryBody> {
  OrderFilter _filter = OrderFilter.all;

  @override
  Widget build(BuildContext context) => ref
      .watch(supplyOrdersProvider(widget.houseId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SupplyFailure(
          e,
          () => ref.invalidate(supplyOrdersProvider(widget.houseId)),
        ),
        data: (orders) {
          final unpaidOrders = orders
              .where((o) =>
                  o['status'] != 'PAID' &&
                  o['paymentConfirmationSource'] == null)
              .toList();
          final paidOrders = orders
              .where((o) =>
                  o['status'] == 'PAID' ||
                  o['paymentConfirmationSource'] != null)
              .toList();

          final showUnpaid = (_filter == OrderFilter.all ||
                  _filter == OrderFilter.unpaid) &&
              unpaidOrders.isNotEmpty;
          final showPaid = (_filter == OrderFilter.all ||
                  _filter == OrderFilter.paid) &&
              paidOrders.isNotEmpty;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(supplyOrdersProvider(widget.houseId));
              await ref.read(supplyOrdersProvider(widget.houseId).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 88),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(
                        selected: _filter == OrderFilter.all,
                        onTap: () => setState(() => _filter = OrderFilter.all),
                        label: 'All Orders',
                        count: orders.length,
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        selected: _filter == OrderFilter.unpaid,
                        onTap: () =>
                            setState(() => _filter = OrderFilter.unpaid),
                        label: 'Unpaid',
                        count: unpaidOrders.length,
                        dotColor: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        selected: _filter == OrderFilter.paid,
                        onTap: () => setState(() => _filter = OrderFilter.paid),
                        label: 'Paid',
                        count: paidOrders.length,
                        dotColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
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
                if (showUnpaid) ...[
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD97706),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'PAYMENT PENDING (${unpaidOrders.length})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Needs action',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final order in unpaidOrders)
                    _UnpaidOrderCard(
                      order: order,
                      houseId: widget.houseId,
                    ),
                  const SizedBox(height: 12),
                ],
                if (showPaid) ...[
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF059669),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'PAID & SETTLED (${paidOrders.length})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: Color(0xFF047857),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final order in paidOrders)
                    _PaidOrderCard(
                      order: order,
                      houseId: widget.houseId,
                    ),
                ],
                if (orders.isNotEmpty && !showUnpaid && !showPaid)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        _filter == OrderFilter.unpaid
                            ? 'No pending unpaid orders.'
                            : 'No settled paid orders yet.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );

  Widget _filterChip({
    required bool selected,
    required VoidCallback onTap,
    required String label,
    required int count,
    Color? dotColor,
  }) {
    if (selected) {
      return Material(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: dotColor != null
                      ? dotColor.withValues(alpha: 0.12)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: dotColor ?? const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnpaidOrderCard extends StatelessWidget {
  const _UnpaidOrderCard({required this.order, required this.houseId});
  final SupplyData order;
  final String houseId;

  @override
  Widget build(BuildContext context) {
    final shortId = order['id'].toString().split('-').first;
    final supplierName = order['supplierName']?.toString().isNotEmpty == true
        ? order['supplierName'].toString()
        : 'Order #$shortId';
    final items = _itemsSummary(order);
    final dateStr = _formatOrderDate(order, false);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1ECE7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFFF59E0B), width: 4.5),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  context.push('/houses/$houseId/orders/${order['id']}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Color(0xFF7C4DFF),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            supplierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: Color(0xFFD97706),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Unpaid',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Color(0xFF1E293B)),
                        children: [
                          TextSpan(
                            text: supplyMoney(order['total']),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (items.isNotEmpty)
                            TextSpan(
                              text: '  · $items',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12.5,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order ID: #ORD-$shortId',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(
                            '/houses/$houseId/orders/${order['id']}',
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            foregroundColor: const Color(0xFF334155),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => context.push(
                            '/houses/$houseId/orders/${order['id']}?payNow=1',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7C4DFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Pay Now',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_forward_rounded, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaidOrderCard extends StatelessWidget {
  const _PaidOrderCard({required this.order, required this.houseId});
  final SupplyData order;
  final String houseId;

  @override
  Widget build(BuildContext context) {
    final shortId = order['id'].toString().split('-').first;
    final supplierName = order['supplierName']?.toString().isNotEmpty == true
        ? order['supplierName'].toString()
        : 'Order #$shortId';
    final items = _itemsSummary(order);
    final dateStr = _formatOrderDate(order, true);
    final (sourceIcon, sourceLabel) = _paymentSource(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1ECE7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF10B981), width: 4.5),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  context.push('/houses/$houseId/orders/${order['id']}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Color(0xFF059669),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            supplierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Color(0xFF059669),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Paid',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Color(0xFF1E293B)),
                        children: [
                          TextSpan(
                            text: supplyMoney(order['total']),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (items.isNotEmpty)
                            TextSpan(
                              text: '  · $items',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 12.5,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sourceIcon,
                              size: 15,
                              color: const Color(0xFF059669),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              sourceLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/houses/$houseId/orders/${order['id']}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.receipt_outlined, size: 14),
                          label: const Text(
                            'Receipt',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _itemsSummary(SupplyData order) {
  final lines = (order['lines'] as List? ?? []).cast<Map>();
  if (lines.isEmpty) return '';
  return lines
      .map((l) {
        final qty = l['quantity'] ?? 1;
        final name = l['name'] ?? '';
        final unit =
            l['unit']?.toString().isNotEmpty == true ? ' ${l['unit']}' : '';
        return '$qty$unit $name'.trim();
      })
      .where((s) => s.isNotEmpty)
      .join(', ');
}

String _formatOrderDate(SupplyData order, bool isPaid) {
  final rawDate = isPaid
      ? (order['paidAt'] ?? order['paymentRecordedAt'] ?? order['createdAt'])
      : (order['createdAt'] ?? order['updatedAt']);
  if (rawDate == null) return isPaid ? 'Payment recorded' : 'Order saved';
  try {
    final dt = DateTime.parse(rawDate.toString()).toLocal();
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(dt);
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, $timeStr · ${isPaid ? 'Payment recorded' : 'Order saved'}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday, $timeStr · ${isPaid ? 'Payment recorded' : 'Order saved'}';
    }
    return '${DateFormat('dd MMM, HH:mm').format(dt)} · ${isPaid ? 'Payment recorded' : 'Order saved'}';
  } catch (_) {
    return isPaid ? 'Payment recorded' : 'Order saved';
  }
}

(IconData, String) _paymentSource(SupplyData order) {
  final source = order['paymentConfirmationSource']?.toString();
  final ref = order['paymentReference']?.toString() ?? '';
  if (source == 'PAYOS_VERIFIED') {
    return (Icons.shield_outlined, 'PayOS Verified');
  }
  if (ref.startsWith('CASH')) {
    return (Icons.payments_outlined, 'Cash Payment');
  }
  if (ref.startsWith('QR')) {
    return (Icons.qr_code_2_rounded, 'VietQR Transfer');
  }
  return (Icons.account_balance_outlined, 'Bank Transfer');
}
