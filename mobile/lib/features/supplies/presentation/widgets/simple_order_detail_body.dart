import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import 'supplies_ui.dart';
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

class _SimpleOrderDetailBodyState extends ConsumerState<SimpleOrderDetailBody>
    with WidgetsBindingObserver {
  SupplyData? _payment;
  bool _busy = false;
  bool _refreshing = false;
  bool _autoStarted = false;
  bool _localPaid = false;
  String? _error;
  Timer? _poll;

  bool get _paid =>
      _localPaid ||
      widget.order['status'] == 'PAID' ||
      widget.order['paymentConfirmationSource'] != null ||
      _payment?['status'] == 'VERIFIED';

  bool get _paymentLinkExpired {
    final expiresAt = DateTime.tryParse(
      _payment?['expiresAt']?.toString() ?? '',
    );
    return expiresAt != null &&
        !expiresAt.toUtc().isAfter(DateTime.now().toUtc());
  }

  String get _qrPayload {
    final fromGateway = _payment?['qrCode']?.toString().trim() ?? '';
    if (_paymentLinkExpired) return '';
    return fromGateway;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _queueAutoCheckout();
    if (!_paid) {
      unawaited(_refreshPayment(silent: true));
      _poll = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _refreshPayment(silent: true),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_paid) {
      unawaited(_refreshPayment(silent: true));
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
    WidgetsBinding.instance.removeObserver(this);
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
      if (result['status'] == 'VERIFIED') {
        _poll?.cancel();
        _invalidateOrderAndDebts();
        return;
      }
      final url = result['checkoutUrl']?.toString() ?? '';
      if (url.isNotEmpty) await supplyLaunch(context, Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshPayment({bool silent = false}) async {
    if (_busy || _paid || _refreshing) return;
    _refreshing = true;
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
      _invalidateOrderAndDebts();
      if (result['status'] == 'VERIFIED') _poll?.cancel();
    } catch (e) {
      if (!silent && mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      _refreshing = false;
      if (!silent && mounted) setState(() => _busy = false);
    }
  }

  void _invalidateOrderAndDebts() {
    ref.invalidate(
      supplyOrderProvider((
        house: widget.houseId,
        id: widget.order['id'].toString(),
      )),
    );
    ref.invalidate(supplyOrdersProvider(widget.houseId));
    ref.invalidate(purchaseDebtsProvider(widget.houseId));
  }

  Future<void> _payWithCash(String shortId) async {
    if (_busy || _paid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(suppliesRepositoryProvider).mutate(
        '/houses/${widget.houseId}/orders/${widget.order['id']}/record-payment',
        {
          'clientRequestId': const Uuid().v4(),
          'amount': widget.order['total'],
          'reference': 'CASH:CW-$shortId',
        },
      );
      if (!mounted) return;
      setState(() => _localPaid = true);
      ref.invalidate(
        supplyOrderProvider((
          house: widget.houseId,
          id: widget.order['id'].toString(),
        )),
      );
      ref.invalidate(supplyOrdersProvider(widget.houseId));
      ref.invalidate(purchaseDebtsProvider(widget.houseId));
    } catch (e) {
      if (!mounted) return;
      final msg = apiErrorMessage(e);
      if (msg.contains('PayOS') || msg.contains('not configured')) {
        setState(() {
          _localPaid = true;
          _error = null;
        });
        ref.invalidate(supplyOrdersProvider(widget.houseId));
        ref.invalidate(purchaseDebtsProvider(widget.houseId));
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final recorded = _paid;
    final shortId = widget.order['id'].toString().split('-').first;
    final lines = widget.order['lines'] as List? ?? [];
    final qrPayload = _qrPayload;

    return ListView(
      cacheExtent: 0,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
      children: [
        SupplySurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF7C4DFF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order $shortId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ordered by ${person(widget.order['creatorUserId'])}',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: recorded
                          ? const Color(0xFFE6F7F0)
                          : const Color(0xFFEDE7FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      recorded ? 'Paid' : 'Order saved',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: recorded
                            ? const Color(0xFF0D9F6E)
                            : const Color(0xFF6845D6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${line['quantity']}×',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${line['quantity']} × ${line['name']} · ${supplyMoney(line['unitPrice'])} / ${line['unit']}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              Text(
                'Delivery: ${supplyMoney(widget.order['deliveryFee'])}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Total: ${supplyMoney(widget.order['total'])}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7C4DFF),
                ),
              ),
              if (widget.order['note']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.order['note'].toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (sms) ...[
          const SizedBox(height: 14),
          SupplySurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SMS order message',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Send the prepared message in your SMS app. Sending an SMS does not confirm payment.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          supplyOpenOrderSms(context, widget.order),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFEDE7FF),
                        foregroundColor: const Color(0xFF6845D6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.sms_outlined, size: 16),
                      label: const Text('Open SMS'),
                    ),
                    TextButton.icon(
                      onPressed: () => supplyCopy(
                        context,
                        'Order message',
                        supplySmsBody(widget.order),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF334155),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy message'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SupplySurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cost shares',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < shares.length; i++) ...[
                if (i > 0) const Divider(height: 18, color: Color(0xFFF1F5F9)),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            shares[i]['userId'] == widget.order['payerUserId']
                            ? const Color(0xFFEDE7FF)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        person(shares[i]['userId']).characters.first
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              shares[i]['userId'] == widget.order['payerUserId']
                              ? const Color(0xFF6845D6)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person(shares[i]['userId']),
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
                            shares[i]['userId'] == widget.order['payerUserId']
                                ? 'Pays first'
                                : payer
                                ? 'You owe this amount to the payer after payment'
                                : 'Owes ${person(widget.order['payerUserId'])} after payment',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        supplyMoney(shares[i]['amount']),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Debts are created only when PayOS confirms the full payment.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (recorded)
          SupplySurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF0D9F6E),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Payment verified by PayOS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  supplyMoney(
                    widget.order['recordedPaidAmount'] ?? widget.order['total'],
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D9F6E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paid by ${person(widget.order['paymentRecordedByUserId'] ?? widget.order['payerUserId'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      context.push('/houses/${widget.houseId}/account/debts'),
                  child: const Text('View household debts'),
                ),
              ],
            ),
          )
        else
          SupplySurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pay supplier with PayOS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _paymentLinkExpired
                      ? 'This PayOS link expired. Get a fresh checkout link below to pay this saved order.'
                      : qrPayload.isEmpty
                      ? 'Create a PayOS payment to get its verified QR code and checkout link.'
                      : 'Scan the PayOS QR code or open the secure PayOS checkout.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (qrPayload.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF8FF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDED3FF)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C4DFF)
                                    .withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 188,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          supplyMoney(widget.order['total']),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6845D6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transfer content: CW-$shortId',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => supplyCopy(
                            context,
                            'PayOS QR details',
                            qrPayload,
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy payment details'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _startCheckout,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(
                      _busy
                          ? 'Preparing PayOS…'
                          : _payment == null
                          ? 'Create PayOS payment'
                          : 'Open PayOS to pay',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _payWithCash(shortId),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Pay in cash'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _busy ? null : () => _refreshPayment(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Check payment status'),
                ),
                if (_payment != null && _payment!['status'] != null)
                  Text(
                    'PayOS status: ${_payment!['status']}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
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
