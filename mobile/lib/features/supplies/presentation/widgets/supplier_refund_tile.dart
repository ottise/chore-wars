import 'package:flutter/material.dart';

import '../../domain/repositories/supplies_repository.dart';
import 'supplies_ui.dart';

class SupplierRefundTile extends StatelessWidget {
  const SupplierRefundTile({
    required this.refund,
    this.onConfirm,
    this.onReject,
    super.key,
  });
  final SupplyData refund;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SupplySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supplier refund · ${supplyMoney(refund['amount'])}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${refund['reason']}\n${refund['reference']}'),
          if (refund['confirmedAt'] != null)
            const Text('Payer acknowledged receipt')
          else if (refund['rejectedAt'] != null)
            const Text('Payer rejected this refund report')
          else if (onConfirm != null || onReject != null)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: onConfirm,
                  child: const Text('I received it'),
                ),
                TextButton(
                  onPressed: onReject,
                  child: const Text('Not received'),
                ),
              ],
            )
          else
            const Text('Awaiting payer confirmation'),
        ],
      ),
    ),
  );
}
