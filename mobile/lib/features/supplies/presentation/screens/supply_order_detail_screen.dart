import '../widgets/supplier_refund_tile.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import '../widgets/supplies_ui.dart';
import '../widgets/supply_disputes_panel.dart';

final supplyRefundsProvider = FutureProvider.autoDispose
    .family<List<SupplyData>, String>(
      (ref, id) => ref
          .watch(suppliesRepositoryProvider)
          .list('/supply-orders/$id/refunds'),
    );

class SupplyOrderDetailScreen extends ConsumerStatefulWidget {
  const SupplyOrderDetailScreen({
    required this.houseId,
    required this.orderId,
    super.key,
  });
  final String houseId;
  final String orderId;
  @override
  ConsumerState<SupplyOrderDetailScreen> createState() =>
      _SupplyOrderDetailScreenState();
}

class _SupplyOrderDetailScreenState
    extends ConsumerState<SupplyOrderDetailScreen> {
  bool _busy = false;
  String? _error;
  SupplyData? _checkout;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(
          supplyOrderProvider((house: widget.houseId, id: widget.orderId)),
        );
        ref.invalidate(supplyOrdersProvider(widget.houseId));
        ref.invalidate(purchaseDebtsProvider(widget.houseId));
        ref.invalidate(supplyRefundsProvider(widget.orderId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (house: widget.houseId, id: widget.orderId);
    final me = ref.watch(userProfileProvider).asData?.value.id;
    return SuppliesPage(
      title: 'Purchase detail',
      child: ref
          .watch(supplyOrderProvider(key))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SupplyFailure(
              e,
              () => ref.invalidate(supplyOrderProvider(key)),
            ),
            data: (o) {
              final status = o['status'].toString();
              final isPayer = me == o['payerUserId'];
              final isCreator = me == o['creatorUserId'];
              final shares = (o['shares'] as List? ?? []).cast<Map>();
              final mine = shares.where((s) => s['userId'] == me).firstOrNull;
              Future<void> action(
                String name, [
                SupplyData extra = const {},
              ]) async {
                await ref.read(suppliesRepositoryProvider).action(
                  widget.houseId,
                  widget.orderId,
                  name,
                  {'expectedVersion': o['version'], ...extra},
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
                          status.replaceAll('_', ' '),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('${o['supplierName']} · ${o['supplierPhone']}'),
                        for (final line in o['lines'] as List)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '${line['quantity']} × ${line['name']} · ${supplyMoney(line['unitPrice'])} / ${line['unit']}',
                            ),
                          ),
                        const Divider(height: 28),
                        Text('Delivery: ${supplyMoney(o['deliveryFee'])}'),
                        Text(
                          'Total: ${supplyMoney(o['total'])}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if ((o['refundedAmount'] as num? ?? 0) > 0)
                          Text(
                            'Refund acknowledged: ${supplyMoney(o['refundedAmount'])}',
                          ),
                        const SizedBox(height: 12),
                        Text(o['deliveryAddress'].toString()),
                        Text(o['contactPhone'].toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Cost shares',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SupplySurface(
                    child: Column(
                      children: [
                        for (final s in shares)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(s['displayName'].toString()),
                            subtitle: Text(
                              s['userId'] == o['payerUserId']
                                  ? 'Pays the supplier first'
                                  : 'Repays the payer directly',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(supplyMoney(s['amount'])),
                                Text(
                                  s['rejected'] == true
                                      ? 'Declined'
                                      : s['approved'] == true
                                      ? 'Approved'
                                      : 'Awaiting approval',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_busy) const LinearProgressIndicator(),
                  if ([
                        'DRAFT',
                        'AWAITING_APPROVAL',
                        'APPROVED',
                      ].contains(status) &&
                      isCreator)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => context.push(
                              '/houses/${widget.houseId}/supplies',
                              extra: {
                                'revise_order_id': widget.orderId,
                                'expected_version': o['version'],
                                'supplier_id': o['supplierId'],
                                'via_ai': o['createdVia'] == 'AI',
                                'payer_id': o['payerUserId'],
                                'participant_ids': shares
                                    .map((s) => s['userId'])
                                    .toList(),
                                'share_amounts': {
                                  for (final s in shares)
                                    s['userId'].toString(): s['amount'],
                                },
                                'delivery_address': o['deliveryAddress'],
                                'contact_phone': o['contactPhone'],
                                'lines': (o['lines'] as List)
                                    .map(
                                      (l) => {
                                        'product_id': l['productId'],
                                        'quantity': l['quantity'],
                                      },
                                    )
                                    .toList(),
                              },
                            ),
                      child: const Text('Revise purchase'),
                    ),
                  if (status == 'DRAFT' && isCreator)
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => action('submit')),
                      child: const Text('Send for approval'),
                    ),
                  if (status == 'AWAITING_APPROVAL' &&
                      mine != null &&
                      mine['approved'] != true) ...[
                    const Text(
                      'Approve your share and, if you are the payer, advancing the full order amount. No money is moved by approving.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => action('approve', {'approve': true}),
                            ),
                      child: const Text('Approve my share'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => action('approve', {'approve': false}),
                            ),
                      child: const Text('Decline purchase'),
                    ),
                  ],
                  if (status == 'APPROVED' && isPayer) ...[
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final data = await ref
                                  .read(suppliesRepositoryProvider)
                                  .action(
                                    widget.houseId,
                                    widget.orderId,
                                    'checkout',
                                    {'expectedVersion': o['version']},
                                  );
                              if (mounted) setState(() => _checkout = data);
                            }),
                      child: const Text('Checkout with payOS'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final p = await ref
                                  .read(suppliesRepositoryProvider)
                                  .get(
                                    '/houses/${widget.houseId}/supply-orders/${widget.orderId}/payment',
                                  );
                              if (mounted) setState(() => _checkout = p);
                            }),
                      child: const Text('Check payment status'),
                    ),
                  ],
                  if (_checkout != null &&
                      _checkout!['status'] != 'VERIFIED') ...[
                    Text('Payment: ${_checkout!['status'] ?? 'Not created'}'),
                    if ((_checkout!['qrCode']?.toString() ?? '').isNotEmpty)
                      Center(
                        child: QrImageView(
                          data: _checkout!['qrCode'].toString(),
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    if ((_checkout!['checkoutUrl']?.toString() ?? '')
                        .isNotEmpty) ...[
                      FilledButton(
                        onPressed: () => supplyLaunch(
                          context,
                          Uri.parse(_checkout!['checkoutUrl'].toString()),
                        ),
                        child: const Text('Open secure checkout'),
                      ),
                      TextButton(
                        onPressed: () => supplyCopy(
                          context,
                          'Checkout link',
                          _checkout!['checkoutUrl'].toString(),
                        ),
                        child: const Text('Copy checkout link'),
                      ),
                    ],
                    const Text(
                      'Opening checkout does not confirm payment. Use Check payment status after paying.',
                    ),
                  ],
                  if (status == 'DELIVERED' && (isPayer || isCreator))
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => action('receive')),
                      child: const Text('Confirm goods received'),
                    ),
                  if ([
                        'DRAFT',
                        'AWAITING_APPROVAL',
                        'APPROVED',
                      ].contains(status) &&
                      (isPayer || isCreator))
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => action('cancel')),
                      child: const Text('Cancel purchase'),
                    ),
                  if (o['paidAt'] != null ||
                      [
                        'PAID',
                        'FULFILLING',
                        'DELIVERED',
                        'COMPLETED',
                        'REFUNDED',
                      ].contains(status))
                    TextButton(
                      onPressed: () => context.push(
                        '/houses/${widget.houseId}/supplies/debts',
                      ),
                      child: const Text('View direct reimbursements'),
                    ),
                  SupplyDisputesPanel(
                    orderId: widget.orderId,
                    canReport:
                        mine != null &&
                        [
                          'PAID',
                          'FULFILLING',
                          'DELIVERED',
                          'COMPLETED',
                          'REFUNDED',
                        ].contains(status),
                  ),
                  ref
                      .watch(supplyRefundsProvider(widget.orderId))
                      .when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) => SupplyFailure(
                          e,
                          () => ref.invalidate(
                            supplyRefundsProvider(widget.orderId),
                          ),
                        ),
                        data: (refunds) => Column(
                          children: [
                            for (final r in refunds)
                              SupplierRefundTile(
                                refund: Map<String, dynamic>.from(r),
                                onConfirm: isPayer && !_busy
                                    ? () => _run(() async {
                                        await ref
                                            .read(suppliesRepositoryProvider)
                                            .mutate(
                                              '/supply-orders/${widget.orderId}/refunds/${r['id']}/confirm',
                                              {},
                                            );
                                      })
                                    : null,
                                onReject: isPayer && !_busy
                                    ? () => _run(() async {
                                        await ref
                                            .read(suppliesRepositoryProvider)
                                            .mutate(
                                              '/supply-orders/${widget.orderId}/refunds/${r['id']}/reject',
                                              {},
                                            );
                                      })
                                    : null,
                              ),
                          ],
                        ),
                      ),
                ],
              );
            },
          ),
    );
  }
}

class SupplyOrderHistoryScreen extends ConsumerWidget {
  const SupplyOrderHistoryScreen({required this.houseId, super.key});
  final String houseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => SuppliesPage(
    title: 'Purchase history',
    child: ref
        .watch(supplyOrdersProvider(houseId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => SupplyFailure(
            e,
            () => ref.invalidate(supplyOrdersProvider(houseId)),
          ),
          data: (items) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(supplyOrdersProvider(houseId));
              await ref.read(supplyOrdersProvider(houseId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (items.isEmpty) const Text('No purchases yet.'),
                for (final o in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SupplySurface(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(o['supplierName'].toString()),
                        subtitle: Text(
                          '${o['status']} · ${supplyMoney(o['total'])}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/houses/$houseId/supplies/orders/${o['id']}',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
  );
}
