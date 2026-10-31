import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import '../widgets/supplies_ui.dart';
import '../widgets/debt_action_sheet.dart';
import '../../../payment/presentation/providers/payment_history_provider.dart';
import '../../../house/presentation/providers/household_summary_provider.dart';

final purchaseDebtProvider = FutureProvider.autoDispose
    .family<SupplyData, ({String house, String id})>(
      (ref, key) => ref
          .watch(suppliesRepositoryProvider)
          .get('/houses/${key.house}/me/debts/${key.id}'),
    );
final repaymentInstructionsProvider = FutureProvider.autoDispose
    .family<SupplyData, String>(
      (ref, id) => ref
          .watch(suppliesRepositoryProvider)
          .get('/payment-obligations/$id/instructions'),
    );

class HouseholdDebtsScreen extends ConsumerWidget {
  const HouseholdDebtsScreen({required this.houseId, super.key});
  final String houseId;
  Future<void> _actions(
    BuildContext context,
    WidgetRef ref,
    Map debt,
    String? me,
  ) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DebtActionSheet(
        houseId: houseId,
        debt: Map<String, dynamic>.from(debt),
        debtor: debt['debtorUserId'] == me,
      ),
    );
    ref.invalidate(
      purchaseDebtProvider((house: houseId, id: debt['id'].toString())),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(userProfileProvider).asData?.value.id;
    if (me == null) {
      return SuppliesPage(
        title: 'My Debts',
        child: ref
            .watch(userProfileProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  SupplyFailure(e, () => ref.invalidate(userProfileProvider)),
              data: (_) =>
                  const Center(child: Text('Sign in to view your finances.')),
            ),
      );
    }
    return SuppliesPage(
      title: 'My Debts',
      child: ref
          .watch(purchaseDebtsProvider(houseId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SupplyFailure(
              e,
              () => ref.invalidate(purchaseDebtsProvider(houseId)),
            ),
            data: (summary) {
              final rows = (summary['debts'] as List? ?? [])
                  .cast<Map>()
                  .where((d) => (d['remainingAmount'] as num? ?? 0) > 0)
                  .toList();
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(purchaseDebtsProvider(houseId));
                  await ref.read(purchaseDebtsProvider(houseId).future);
                },
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SupplySurface(
                      child: Column(
                        children: [
                          for (final entry in {
                            'owe': 'I owe',
                            'owedToMe': 'Owed to me',
                          }.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(child: Text(entry.value)),
                                  Text(supplyMoney(summary[entry.key])),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.push('/bank-accounts'),
                        icon: const Icon(Icons.account_balance_outlined),
                        label: const Text('Receiving account'),
                      ),
                    ),
                    const Text(
                      'Direct debts are kept separately. No debts are transferred to another person or offset.',
                    ),
                    const SizedBox(height: 16),
                    if (rows.isEmpty)
                      const Text(
                        'No outstanding debts. Settled transfers are in Payment History.',
                      ),
                    for (final owe in [true, false]) ...[
                      Text(
                        owe ? 'I owe' : 'Owed to me',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final d in rows.where(
                        (d) => (d['debtorUserId'] == me) == owe,
                      ))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: SupplySurface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    owe
                                        ? 'Pay ${d['creditorName']}'
                                        : '${d['debtorName']} owes you',
                                  ),
                                  subtitle: Text(
                                    '${supplyMoney(d['remainingAmount'])} remaining · ${financeSourceLabel(d['reason'])} · ${d['status'] == 'AWAITING_COMPLETION'
                                        ? 'Awaiting chore completion'
                                        : d['status'] == 'DISPUTED'
                                        ? 'Disputed'
                                        : 'Pending'}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push(
                                    '/houses/$houseId/account/debts/${d['id']}',
                                  ),
                                ),
                                if ((d['remainingAmount'] as num? ?? 0) > 0 &&
                                    d['status'] == 'PENDING')
                                  TextButton.icon(
                                    onPressed: () =>
                                        _actions(context, ref, d, me),
                                    icon: Icon(
                                      owe ? Icons.north_east : Icons.south_west,
                                    ),
                                    label: Text(
                                      owe ? 'Mark as paid' : 'Confirm received',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              );
            },
          ),
    );
  }
}

class InternalRepaymentScreen extends ConsumerStatefulWidget {
  const InternalRepaymentScreen({
    required this.houseId,
    required this.debtId,
    super.key,
  });
  final String houseId;
  final String debtId;
  @override
  ConsumerState<InternalRepaymentScreen> createState() =>
      _InternalRepaymentScreenState();
}

class _InternalRepaymentScreenState
    extends ConsumerState<InternalRepaymentScreen> {
  String _requestId = const Uuid().v4();
  bool _busy = false;
  String? _error;

  Future<void> _run(String path, SupplyData request) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(suppliesRepositoryProvider).mutate(path, request);
      if (mounted) {
        _requestId = const Uuid().v4();
        ref.invalidate(
          purchaseDebtProvider((house: widget.houseId, id: widget.debtId)),
        );
        ref.invalidate(repaymentInstructionsProvider(widget.debtId));
        ref.invalidate(purchaseDebtsProvider(widget.houseId));
        ref.invalidate(paymentHistoryProvider);
        ref.invalidate(householdSummaryProvider);
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(userProfileProvider).asData?.value.id;
    if (me == null) {
      return SuppliesPage(
        title: 'My Debts',
        child: ref
            .watch(userProfileProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  SupplyFailure(e, () => ref.invalidate(userProfileProvider)),
              data: (_) =>
                  const Center(child: Text('Sign in to view your finances.')),
            ),
      );
    }
    return SuppliesPage(
      title: 'Direct repayment',
      child: ref
          .watch(
            purchaseDebtProvider((house: widget.houseId, id: widget.debtId)),
          )
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SupplyFailure(
              e,
              () => ref.invalidate(
                purchaseDebtProvider((
                  house: widget.houseId,
                  id: widget.debtId,
                )),
              ),
            ),
            data: (d) {
              final debtor = d['debtorUserId'] == me;
              final remaining = d['remainingAmount'] as num? ?? 0;
              final repayments = (d['repayments'] as List? ?? [])
                  .cast<Map<dynamic, dynamic>>();
              final pending = repayments
                  .where((r) => r['status'] == 'REPORTED')
                  .toList();
              final pendingAmount = pending.fold<num>(
                0,
                (sum, r) => sum + (r['amount'] as num? ?? 0),
              );
              final availableToReport = remaining - pendingAmount;
              final isPayable = d['status'] == 'PENDING' && remaining > 0;
              final awaitingCompletion = d['status'] == 'AWAITING_COMPLETION';

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  SupplySurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${d['debtorName']} → ${d['creditorName']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text('Original: ${supplyMoney(d['originalAmount'])}'),
                        Text('Adjustments: ${supplyMoney(d['adjustments'])}'),
                        Text(
                          'Confirmed transfers: ${supplyMoney(d['confirmedAmount'])}',
                        ),
                        const Divider(),
                        Text(
                          'Remaining: ${supplyMoney(remaining)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  if (d['sourceOrderId'] != null)
                    TextButton(
                      onPressed: () => context.push(
                        '/houses/${widget.houseId}/supplies/orders/${d['sourceOrderId']}',
                      ),
                      child: const Text('View source purchase'),
                    ),
                  if (awaitingCompletion) ...[
                    const SizedBox(height: 16),
                    const SupplySurface(
                      child: Text(
                        'This obligation is awaiting chore completion before payment can be confirmed.',
                      ),
                    ),
                  ],
                  if (!debtor && isPayable) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => pending.isNotEmpty
                                ? _run(
                                    '/payment-obligations/${widget.debtId}/repayments/${pending.first['id']}/respond',
                                    {'confirm': true},
                                  )
                                : _run(
                                    '/payment-obligations/${widget.debtId}/record-receipt',
                                    {
                                      'clientRequestId': _requestId,
                                      'amount': remaining,
                                      'reference': '',
                                    },
                                  ),
                      child: const Text('Confirm'),
                    ),
                  ],
                  if (debtor && remaining > 0) ...[
                    const SizedBox(height: 16),
                    ref
                        .watch(repaymentInstructionsProvider(widget.debtId))
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => SupplyFailure(
                            e,
                            () => ref.invalidate(
                              repaymentInstructionsProvider(widget.debtId),
                            ),
                          ),
                          data: (instructions) {
                            final bank = instructions['bankAccount'] as Map?;
                            return SupplySurface(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pay ${d['creditorName']} directly',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  if (bank == null)
                                    const Text(
                                      'Bank details not added yet. Contact the recipient to arrange a transfer.',
                                    )
                                  else ...[
                                    Text(
                                      '${bank['bankName']}\n${bank['accountName']}\n${bank['accountNumber']}',
                                    ),
                                    const Text(
                                      'Self-declared bank details. Verify the recipient in your bank before transferring.',
                                    ),
                                    TextButton(
                                      onPressed: () => supplyCopy(
                                        context,
                                        'Account number',
                                        bank['accountNumber'].toString(),
                                      ),
                                      child: const Text('Copy account number'),
                                    ),
                                  ],
                                  TextButton(
                                    onPressed: () => supplyCopy(
                                      context,
                                      'Reference',
                                      instructions['reference'].toString(),
                                    ),
                                    child: Text(
                                      'Copy reference: ${instructions['reference']}',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => supplyCopy(
                                      context,
                                      'Amount',
                                      remaining.toStringAsFixed(0),
                                    ),
                                    child: const Text('Copy remaining amount'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    if (isPayable && availableToReport > 0) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Transfer using your bank, then confirm here. Only the recipient can confirm receipt.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                '/payment-obligations/${widget.debtId}/repayments',
                                {
                                  'clientRequestId': _requestId,
                                  'amount': availableToReport,
                                  'reference': '',
                                },
                              ),
                        child: const Text('Confirm'),
                      ),
                    ] else if (pendingAmount > 0) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Waiting for ${d['creditorName']} to confirm receipt.',
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_busy) const LinearProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Transfer history',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (repayments.isEmpty)
                    const Text('No transfers reported yet.'),
                  for (final r in repayments)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SupplySurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supplyMoney(r['amount'])),
                            Text('Debt · ${r['status']}'),
                            if (r['responseReason'] != null)
                              Text(r['responseReason'].toString()),
                            if (!debtor &&
                                isPayable &&
                                r['status'] == 'REPORTED') ...[
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        '/payment-obligations/${widget.debtId}/repayments/${r['id']}/respond',
                                        {'confirm': true},
                                      ),
                                child: const Text('Confirm'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
    );
  }
}
