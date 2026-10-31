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
    required this.debtor,
    super.key,
  });
  final String houseId;
  final Map<String, dynamic> debt;
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
                      ? 'Pay ${widget.debt['creditorName']}'
                      : '${widget.debt['debtorName']} owes you',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text('Remaining: ${supplyMoney(remaining)}'),
                for (final transfer in pending)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SupplySurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${supplyMoney(transfer['amount'])} · Awaiting confirmation',
                          ),
                          if (!widget.debtor) ...[
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      'repayments/${transfer['id']}/respond',
                                      {'confirm': true},
                                    ),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (remaining > 0 &&
                    (widget.debtor ? maximum > 0 : pending.isEmpty)) ...[
                  const SizedBox(height: 16),
                  Text(
                    widget.debtor
                        ? 'Confirm that you transferred ${supplyMoney(maximum)}. The recipient must confirm receipt.'
                        : 'Confirm that you received ${supplyMoney(remaining)}.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            widget.debtor ? 'repayments' : 'record-receipt',
                            {
                              'clientRequestId': _request,
                              'amount': (widget.debtor ? maximum : remaining)
                                  .toInt(),
                              'reference': '',
                            },
                          ),
                    child: Text(_busy ? 'Saving…' : 'Confirm'),
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
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
