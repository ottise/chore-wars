import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    return SuppliesPage(
      title: 'Payment History',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month - 1);
                    _page = 1;
                  }),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month + 1);
                    _page = 1;
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in {
                'ALL': 'All',
                'IN': 'Money in',
                'OUT': 'Money out',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _direction == entry.key,
                  onSelected: (_) => setState(() {
                    _direction = entry.key;
                    _page = 1;
                  }),
                ),
            ],
          ),
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
                  data: (data) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(paymentHistoryProvider(query));
                      await ref.read(paymentHistoryProvider(query).future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SupplySurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Confirmed money in: ${supplyMoney(data['moneyIn'])}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Confirmed money out: ${supplyMoney(data['moneyOut'])}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if ((data['items'] as List? ?? []).isEmpty)
                          const Text('No transactions for this period.'),
                        for (final item in data['items'] as List? ?? [])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SupplySurface(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  item['direction'] == 'IN'
                                      ? Icons.south_west
                                      : Icons.north_east,
                                ),
                                title: Text(
                                  '${item['counterparty']} · ${supplyMoney(item['amount'])}',
                                ),
                                subtitle: Text(
                                  '${item['direction'] == 'IN' ? 'Money in' : 'Money out'} · ${financeSourceLabel(item['source'])}\n${DateFormat('MMM d, yyyy').format(vietnamDay(DateTime.parse(item['recordedAt'])))} · ${item['status'] == 'PENDING_CONFIRMATION'
                                      ? 'Pending confirmation'
                                      : item['confirmationSource'] == 'USER_REPORTED'
                                      ? 'Payment recorded by you'
                                      : item['confirmationSource'] == 'RECIPIENT_RECORDED'
                                      ? 'Recorded by recipient'
                                      : item['confirmationSource'] == 'PROVIDER_CONFIRMED'
                                      ? 'Provider confirmed'
                                      : 'Recipient confirmed'}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push(
                                  item['source'] == 'ORDER'
                                      ? '/houses/${widget.houseId}/orders/${item['sourceId']}'
                                      : '/houses/${widget.houseId}/account/debts/${item['sourceId']}',
                                ),
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _page <= 1
                                  ? null
                                  : () => setState(() => _page--),
                              child: const Text('Previous'),
                            ),
                            Text('Page $_page'),
                            TextButton(
                              onPressed:
                                  _page * 30 >=
                                      (data['totalCount'] as num? ?? 0)
                                  ? null
                                  : () => setState(() => _page++),
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
