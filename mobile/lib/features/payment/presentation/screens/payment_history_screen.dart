import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_page_frame.dart';
import '../../../house/domain/entities/house_calendar_models.dart';
import '../../../supplies/presentation/widgets/supplies_ui.dart';
import '../providers/payment_history_provider.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({required this.houseId, super.key});
  final String houseId;
  @override
  ConsumerState<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  late DateTime _month = DateTime(
    vietnamDay(DateTime.now()).year,
    vietnamDay(DateTime.now()).month,
  );
  String _direction = 'ALL';
  int _page = 1;

  static const _purple = Color(0xFF7C4DFF);
  static const _purpleSoft = Color(0xFFEDE9FE);

  String _statusLabel(Map<dynamic, dynamic> item) {
    if (item['status'] == 'PENDING_CONFIRMATION') {
      return 'Pending confirmation';
    }
    return switch (item['confirmationSource']) {
      'USER_REPORTED' => 'Recorded by you',
      'RECIPIENT_RECORDED' => 'Recorded by recipient',
      'PROVIDER_CONFIRMED' => 'Provider confirmed',
      _ => 'Recipient confirmed',
    };
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      house: widget.houseId,
      from: DateFormat('yyyy-MM-dd').format(_month),
      to: DateFormat('yyyy-MM-dd')
          .format(DateTime(_month.year, _month.month + 1, 0)),
      direction: _direction,
      page: _page,
    );

    return AppPageFrame(
      builder: (context) => Scaffold(
        backgroundColor: const Color(0xFFFAF9F6),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/houses/${widget.houseId}');
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Text(
                              'BACK',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const Text(
                          'Finances',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Payment History',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEDEAF6)),
                      ),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              _month = DateTime(_month.year, _month.month - 1);
                              _page = 1;
                            }),
                            child: const Text(
                              'Prev',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              DateFormat('MMMM yyyy').format(_month),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _month = DateTime(_month.year, _month.month + 1);
                              _page = 1;
                            }),
                            child: const Text(
                              'Next',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in {
                          'ALL': 'All',
                          'IN': 'Money in',
                          'OUT': 'Money out',
                        }.entries)
                          _DirectionPill(
                            label: entry.value,
                            selected: _direction == entry.key,
                            onTap: () => setState(() {
                              _direction = entry.key;
                              _page = 1;
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ref
                    .watch(paymentHistoryProvider(query))
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => SupplyFailure(
                        e,
                        () => ref.invalidate(paymentHistoryProvider(query)),
                      ),
                      data: (data) {
                        final items = (data['items'] as List? ?? [])
                            .cast<Map<dynamic, dynamic>>();
                        return Column(
                          children: [
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () async {
                                  ref.invalidate(paymentHistoryProvider(query));
                                  await ref.read(
                                    paymentHistoryProvider(query).future,
                                  );
                                },
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    20,
                                  ),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFEDEAF6),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'MONTHLY SUMMARY',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  'Confirmed money in',
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                supplyMoney(data['moneyIn']),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(
                                            height: 22,
                                            color: Color(0xFFF1F5F9),
                                          ),
                                          Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  'Confirmed money out',
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                supplyMoney(data['moneyOut']),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'TRANSACTIONS',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (items.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          'No transactions for this period.',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    for (final item in items)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Material(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFFEDEAF6),
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () => context.push(
                                              item['source'] == 'ORDER'
                                                  ? '/houses/${widget.houseId}/orders/${item['sourceId']}'
                                                  : '/houses/${widget.houseId}/account/debts/${item['sourceId']}',
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '${item['counterparty']}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Color(
                                                                  0xFF0F172A,
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '${item['direction'] == 'IN' ? '+' : '-'}${supplyMoney(item['amount'])}',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Color(
                                                            0xFF0F172A,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              '${item['direction'] == 'IN' ? 'Money in' : 'Money out'} • ${financeSourceLabel(item['source'])}',
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Color(
                                                                      0xFF64748B,
                                                                    ),
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              '${DateFormat('MMM d, yyyy').format(vietnamDay(DateTime.parse(item['recordedAt'])))} • ${_statusLabel(item)}',
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        11.5,
                                                                    color: Color(
                                                                      0xFF94A3B8,
                                                                    ),
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Text(
                                                        'Details',
                                                        style: TextStyle(
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: _purple,
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
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: _page <= 1
                                        ? null
                                        : () => setState(() => _page--),
                                    child: const Text(
                                      'Previous',
                                      style: TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                  Text(
                                    'Page $_page',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        _page * 30 >=
                                            (data['totalCount'] as num? ?? 0)
                                        ? null
                                        : () => setState(() => _page++),
                                    child: const Text(
                                      'Next',
                                      style: TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionPill extends StatelessWidget {
  const _DirectionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _PaymentHistoryScreenState._purpleSoft : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected
              ? const Color(0xFFC4B5FD)
              : const Color(0xFFE2E8F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? _PaymentHistoryScreenState._purple
                  : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}
