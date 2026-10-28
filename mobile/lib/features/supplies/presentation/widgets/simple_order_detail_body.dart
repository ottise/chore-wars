import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import 'supplies_ui.dart';
import 'supplier_contact_card.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class SimpleOrderDetailBody extends ConsumerWidget {
  const SimpleOrderDetailBody({
    required this.houseId,
    required this.order,
    required this.isCreator,
    required this.busy,
    required this.run,
    this.error,
    super.key,
  });
  final String houseId;
  final SupplyData order;
  final bool isCreator, busy;
  final String? error;
  final Future<void> Function(Future<void> Function()) run;

  Future<void> _record(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController(
      text: (order['total'] as num).toStringAsFixed(0),
    );
    final reference = TextEditingController();
    final requestId = const Uuid().v4();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as paid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Record the money you paid to the supplier. This is your declaration, not a bank verification.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount paid (VND)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reference,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Reference or note (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = num.tryParse(amount.text);
              if (value != null &&
                  value > 0 &&
                  value <= 1000000000 &&
                  value == value.truncateToDouble()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save payment'),
          ),
        ],
      ),
    );
    final value = num.tryParse(amount.text);
    final note = reference.text;
    // Dispose after the dialog route has released its text fields.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      amount.dispose();
      reference.dispose();
    });
    if (accepted != true || value == null) return;
    await run(() async {
      await ref.read(suppliesRepositoryProvider).mutate(
        '/houses/$houseId/orders/${order['id']}/record-payment',
        {'clientRequestId': requestId, 'amount': value, 'reference': note},
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(userProfileProvider).asData?.value;
    final members = ref.watch(houseMembersProvider(houseId)).asData?.value;
    String person(Object? id) => id == null
        ? 'Not recorded'
        : id == me?.id
        ? me!.displayName
        : members?.where((m) => m.userId == id).firstOrNull?.displayName ??
              'Household member';
    final sent = order['emailStatus'] == 'SENT';
    final uncertain = order['emailStatus'] == 'UNKNOWN';
    final recorded = order['paymentConfirmationSource'] != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
      children: [
        SupplierContactCard(
          supplier: {
            'name': order['supplierName'],
            'phone': order['supplierPhone'],
            'email': order['supplierEmail'],
          },
        ),
        const SizedBox(height: 20),
        SupplySurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order ${order['id'].toString().split('-').first}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text('Ordered by ${person(order['creatorUserId'])}'),
              const SizedBox(height: 12),
              for (final line in order['lines'] as List? ?? [])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${line['quantity']} × ${line['name']} · ${supplyMoney(line['unitPrice'])} / ${line['unit']}',
                  ),
                ),
              const Divider(),
              Text('Delivery: ${supplyMoney(order['deliveryFee'])}'),
              Text('Total: ${supplyMoney(order['total'])}'),
              if (order['note']?.toString().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(order['note'].toString()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SupplySurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sent
                    ? 'Email sent'
                    : uncertain
                    ? 'Email result unknown'
                    : order['emailStatus'] == 'FAILED'
                    ? 'Email failed'
                    : 'Sending email…',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                sent
                    ? 'The email service accepted your order. This does not confirm the supplier has read it.'
                    : uncertain
                    ? 'The supplier may have received it. Check before sending again.'
                    : 'The order stays here while the email is processed.',
              ),
              if (isCreator && (uncertain || order['emailStatus'] == 'FAILED'))
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final again = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Send email again?'),
                              content: const Text(
                                'Check with the supplier first if the previous result is unknown. A resend may deliver another email.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Send again'),
                                ),
                              ],
                            ),
                          );
                          if (again == true) {
                            await run(() async {
                              await ref
                                  .read(suppliesRepositoryProvider)
                                  .mutate(
                                    '/houses/$houseId/orders/${order['id']}/retry-email',
                                    {},
                                  );
                            });
                          }
                        },
                  child: const Text('Retry email'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (recorded)
          SupplySurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment recorded',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(supplyMoney(order['recordedPaidAmount'])),
                Text('Recorded by ${person(order['paymentRecordedByUserId'])}'),
                Text(
                  order['paymentConfirmationSource'] == 'USER_REPORTED'
                      ? 'Declared by the person who placed the order; not bank verified.'
                      : 'Verified by the payment provider.',
                ),
                if (order['paymentReference']?.toString().isNotEmpty == true)
                  Text(order['paymentReference'].toString()),
              ],
            ),
          )
        else if (isCreator)
          FilledButton.icon(
            onPressed: sent && !busy ? () => _record(context, ref) : null,
            icon: const Icon(Icons.check_outlined),
            label: const Text('Mark as paid'),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
        Text('Order activity', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in order['activities'] as List? ?? [])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(switch (entry['kind']) {
              'QUEUED' => 'Order email requested',
              'SENT' => 'Email service accepted the order',
              'USER_REPORTED' =>
                'Payment recorded by ${person(entry['actorUserId'])}',
              'UNKNOWN' => 'Email result unknown',
              _ => entry['kind'].toString(),
            }),
            subtitle: Text(
              DateFormat('MMM d, yyyy · HH:mm').format(
                DateTime.parse(entry['recordedAt'].toString()).toLocal(),
              ),
            ),
            trailing: entry['amount'] == null
                ? null
                : Text(supplyMoney(entry['amount'])),
          ),
      ],
    );
  }
}
