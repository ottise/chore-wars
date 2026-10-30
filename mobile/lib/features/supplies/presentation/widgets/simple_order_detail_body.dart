import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import 'supplies_ui.dart';
import 'supplier_contact_card.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class SimpleOrderDetailBody extends ConsumerStatefulWidget {
  const SimpleOrderDetailBody({
    required this.houseId,
    required this.order,
    required this.isCreator,
    this.startCheckout = false,
    super.key,
  });
  final String houseId;
  final SupplyData order;
  final bool isCreator;
  final bool startCheckout;

  @override
  ConsumerState<SimpleOrderDetailBody> createState() =>
      _SimpleOrderDetailBodyState();
}

class _SimpleOrderDetailBodyState extends ConsumerState<SimpleOrderDetailBody> {
  SupplyData? _payment;
  bool _busy = false;
  bool _autoStarted = false;
  String? _error;
  Timer? _poll;

  bool get _paid =>
      widget.order['status'] == 'PAID' ||
      widget.order['paymentConfirmationSource'] == 'PAYOS_VERIFIED';

  @override
  void initState() {
    super.initState();
    _queueAutoCheckout();
    if (!_paid) {
      _poll = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _refreshPayment(silent: true),
      );
    }
  }

  @override
  void didUpdateWidget(covariant SimpleOrderDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order['status'] != widget.order['status'] && _paid) {
      _poll?.cancel();
    }
  }

  void _queueAutoCheckout() {
    if (!widget.startCheckout || _autoStarted) return;
    _autoStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startCheckout();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    if (_busy || _paid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(suppliesRepositoryProvider).mutate(
        '/houses/${widget.houseId}/supply-orders/${widget.order['id']}/checkout',
        {'expectedVersion': widget.order['version']},
      );
      if (!mounted) return;
      setState(() => _payment = result);
      final url = result['checkoutUrl']?.toString() ?? '';
      if (url.isNotEmpty) await supplyLaunch(context, Uri.parse(url));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshPayment({bool silent = false}) async {
    if (_busy || _paid) return;
    if (!silent && mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final result = await ref
          .read(suppliesRepositoryProvider)
          .get(
            '/houses/${widget.houseId}/supply-orders/${widget.order['id']}/payment',
          );
      if (!mounted) return;
      setState(() => _payment = result);
      ref.invalidate(
        supplyOrderProvider((
          house: widget.houseId,
          id: widget.order['id'].toString(),
        )),
      );
      ref.invalidate(supplyOrdersProvider(widget.houseId));
      ref.invalidate(purchaseDebtsProvider(widget.houseId));
    } catch (e) {
      if (!silent && mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (!silent && mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(userProfileProvider).asData?.value;
    final members = ref
        .watch(houseMembersProvider(widget.houseId))
        .asData
        ?.value;
    final shares = (widget.order['shares'] as List? ?? []).cast<Map>();
    String person(Object? id) => id == null
        ? 'Household member'
        : id == me?.id
        ? me!.displayName
        : members?.where((m) => m.userId == id).firstOrNull?.displayName ??
              'Household member';
    final sms = widget.order['workflow'] == 'SIMPLE_SMS';
    final creator = widget.isCreator;
    final payer =
        widget.order['payerUserId'] == me?.id ||
        (widget.order['payerUserId'] == null && creator);
    final recorded = widget.order['paymentConfirmationSource'] != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
      children: [
        SupplierContactCard(
          supplier: {
            'name': widget.order['supplierName'],
            'phone': widget.order['supplierPhone'],
            'email': widget.order['supplierEmail'],
          },
        ),
        const SizedBox(height: 20),
        if (sms)
          SupplySurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order saved'),
                const Text(
                  'Send the prepared message in your SMS app. Sending an SMS does not confirm supplier payment.',
                ),
                TextButton.icon(
                  onPressed: () => supplyOpenOrderSms(context, widget.order),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Open SMS'),
                ),
                TextButton(
                  onPressed: () => supplyCopy(
                    context,
                    'Order message',
                    supplySmsBody(widget.order),
                  ),
                  child: const Text('Copy message'),
                ),
              ],
            ),
          ),
        SupplySurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order ${widget.order['id'].toString().split('-').first}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text('Ordered by ${person(widget.order['creatorUserId'])}'),
              for (final line in widget.order['lines'] as List? ?? [])
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${line['quantity']} × ${line['name']} · ${supplyMoney(line['unitPrice'])} / ${line['unit']}',
                  ),
                ),
              const Divider(height: 28),
              Text('Delivery: ${supplyMoney(widget.order['deliveryFee'])}'),
              Text(
                'Total: ${supplyMoney(widget.order['total'])}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (widget.order['note']?.toString().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(widget.order['note'].toString()),
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
                'Cost shares',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final share in shares)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(person(share['userId'])),
                  subtitle: Text(
                    share['userId'] == widget.order['payerUserId']
                        ? 'Pays the supplier first'
                        : payer
                        ? 'You owe this amount to the payer after payment'
                        : 'Owes this amount to ${person(widget.order['payerUserId'])} after payment',
                  ),
                  trailing: Text(supplyMoney(share['amount'])),
                ),
              const Text(
                'Debts are created only when PayOS confirms the full payment.',
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
                  'Payment verified by PayOS',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(supplyMoney(widget.order['recordedPaidAmount'])),
                Text(
                  'Paid by ${person(widget.order['paymentRecordedByUserId'])}',
                ),
                const Text(
                  'Household reimbursements are available in My Debts.',
                ),
                TextButton(
                  onPressed: () =>
                      context.push('/houses/${widget.houseId}/account/debts'),
                  child: const Text('View household debts'),
                ),
              ],
            ),
          )
        else if (payer)
          SupplySurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay supplier with PayOS',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'The order is confirmed as paid only after PayOS verifies the transfer.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : _payment == null
                      ? _startCheckout
                      : () {
                          final url =
                              _payment?['checkoutUrl']?.toString() ?? '';
                          if (url.isNotEmpty) {
                            supplyLaunch(context, Uri.parse(url));
                          }
                        },
                  icon: const Icon(Icons.payment),
                  label: Text(
                    _busy
                        ? 'Preparing PayOS…'
                        : _payment == null
                        ? 'Create PayOS payment'
                        : 'Open PayOS to pay',
                  ),
                ),
                if ((_payment?['qrCode']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SelectableText(_payment!['qrCode'].toString()),
                  TextButton(
                    onPressed: () => supplyCopy(
                      context,
                      'PayOS QR details',
                      _payment!['qrCode'].toString(),
                    ),
                    child: const Text('Copy payment details'),
                  ),
                ],
                TextButton.icon(
                  onPressed: _busy ? null : () => _refreshPayment(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check payment status'),
                ),
                if (_payment != null)
                  Text('PayOS status: ${_payment!['status']}'),
              ],
            ),
          )
        else
          SupplySurface(
            child: Text(
              'Waiting for ${person(widget.order['payerUserId'])} to pay this order with PayOS.',
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
