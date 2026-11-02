import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../payment/presentation/providers/payment_history_provider.dart';
import '../../../house/presentation/providers/household_summary_provider.dart';
import '../providers/supplies_providers.dart';
import 'supplies_ui.dart';

class DebtActionSheet extends ConsumerStatefulWidget {
  const DebtActionSheet({
    required this.houseId,
    required this.debt,
    this.debts = const [],
    required this.debtor,
    super.key,
  });
  final String houseId;
  final Map<String, dynamic> debt;
  final List<Map<String, dynamic>> debts;
  final bool debtor;
  @override
  ConsumerState<DebtActionSheet> createState() => _DebtActionSheetState();
}

class _DebtActionSheetState extends ConsumerState<DebtActionSheet> {
  final String _request = const Uuid().v4();
  String? _error;
  bool _busy = false;

  Future<void> _run(String suffix, Map<String, dynamic> body) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(suppliesRepositoryProvider)
          .mutate('/payment-obligations/${widget.debt['id']}/$suffix', body);
      ref.invalidate(purchaseDebtsProvider(widget.houseId));
      ref.invalidate(paymentHistoryProvider);
      ref.invalidate(householdSummaryProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = apiErrorMessage(e);
      if (msg.contains('not payable yet') ||
          msg.contains('awaiting chore completion')) {
        ref.invalidate(purchaseDebtsProvider(widget.houseId));
        ref.invalidate(paymentHistoryProvider);
        ref.invalidate(householdSummaryProvider);
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runAll() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = widget.debts.isEmpty ? [widget.debt] : widget.debts;
      if (widget.debtor) {
        for (final debt in rows) {
          final remaining = (debt['remainingAmount'] as num? ?? 0).toDouble();
          final reported = (debt['repayments'] as List? ?? [])
              .where((r) => r['status'] == 'REPORTED')
              .fold<double>(
                0,
                (sum, r) => sum + (r['amount'] as num).toDouble(),
              );
          final amount = remaining - reported;
          if (amount <= 0) continue;
          await ref.read(suppliesRepositoryProvider).mutate(
            '/payment-obligations/${debt['id']}/repayments',
            {
              'clientRequestId': const Uuid().v4(),
              'amount': amount.round(),
              'reference': 'BATCH-$_request',
            },
          );
        }
      } else {
        for (final debt in rows) {
          final reports = (debt['repayments'] as List? ?? []).where(
            (r) => r['status'] == 'REPORTED',
          );
          for (final report in reports) {
            await ref.read(suppliesRepositoryProvider).mutate(
              '/payment-obligations/${debt['id']}/repayments/${report['id']}/respond',
              {'confirm': true},
            );
          }
        }
      }
      ref.invalidate(purchaseDebtsProvider(widget.houseId));
      ref.invalidate(paymentHistoryProvider);
      ref.invalidate(householdSummaryProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = (widget.debt['repayments'] as List? ?? [])
        .where((r) => r['status'] == 'REPORTED')
        .toList();
    final remaining = widget.debt['remainingAmount'] as num;
    final maximum =
        remaining -
        pending.fold<num>(0, (sum, r) => sum + (r['amount'] as num));
    final allDebts = widget.debts.isEmpty ? [widget.debt] : widget.debts;
    final groupRemaining = allDebts.fold<num>(
      0,
      (sum, row) => sum + (row['remainingAmount'] as num? ?? 0),
    );
    final groupPending = allDebts
        .expand((row) => (row['repayments'] as List? ?? []).cast<Map>())
        .where((row) => row['status'] == 'REPORTED')
        .toList();
    final groupPayable = allDebts.fold<num>(0, (sum, row) {
      final outstanding = row['remainingAmount'] as num? ?? 0;
      final reported = (row['repayments'] as List? ?? [])
          .where((r) => r['status'] == 'REPORTED')
          .fold<num>(0, (part, r) => part + (r['amount'] as num? ?? 0));
      return sum + (outstanding - reported).clamp(0, outstanding);
    });
    final debtorName = widget.debt['debtorName']?.toString() ?? 'Người chuyển';
    final creditorName =
        widget.debt['creditorName']?.toString() ?? 'Người nhận';

    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.debtor
                      ? 'Thanh toán cho $creditorName'
                      : 'Xác nhận nhận tiền từ $debtorName',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.debtor
                      ? 'Tài khoản chuyển: $debtorName → Người nhận: $creditorName'
                      : 'Tài khoản xác nhận: $creditorName (Đã nhận từ $debtorName)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Remaining: ${supplyMoney(widget.debts.length > 1 ? groupRemaining : remaining)}',
                ),
                for (final transfer
                    in (widget.debts.length > 1 ? groupPending : pending))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SupplySurface(
                      child: Text(
                        '${supplyMoney(transfer['amount'])} · $debtorName đã báo chuyển, chờ $creditorName xác nhận',
                      ),
                    ),
                  ),
                if ((widget.debts.length > 1 ? groupRemaining : remaining) >
                        0 &&
                    (!widget.debtor ||
                        (widget.debts.length > 1 ? groupPayable : maximum) >
                            0) &&
                    (widget.debtor ||
                        widget.debts.length == 1 ||
                        groupPending.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  Text(
                    widget.debtor
                        ? '$debtorName xác nhận đã chuyển tổng ${supplyMoney(widget.debts.length > 1 ? groupRemaining : maximum)} cho $creditorName. Hệ thống sẽ ghi riêng theo từng đơn; người nhận cần xác nhận.'
                        : '$creditorName xác nhận các khoản đã nhận từ $debtorName.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => widget.debts.length > 1
                              ? _runAll
                              : !widget.debtor && pending.isNotEmpty
                              ? _run(
                                  'repayments/${pending.first['id']}/respond',
                                  {'confirm': true},
                                )
                              : _run(
                                  widget.debtor
                                      ? 'repayments'
                                      : 'record-receipt',
                                  {
                                    'clientRequestId': _request,
                                    'amount':
                                        (widget.debtor ? maximum : remaining)
                                            .toInt(),
                                    'reference': '',
                                  },
                                ),
                    child: Text(
                      _busy
                          ? 'Saving…'
                          : widget.debts.length > 1
                          ? (widget.debtor
                                ? 'Report all payments'
                                : 'Confirm all received')
                          : 'Confirm',
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
