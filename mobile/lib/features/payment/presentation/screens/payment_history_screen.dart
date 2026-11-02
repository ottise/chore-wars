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
  bool _newestFirst = true;

  static const _ink = Color(0xFF292633);
  static const _muted = Color(0xFF827F8B);
  static const _purple = Color(0xFF7046E8);
  static const _green = Color(0xFF07966A);
  static const _red = Color(0xFFDF4561);
  static const _line = Color(0xFFF0EDF3);

  String _statusLabel(Map<dynamic, dynamic> item) {
    if (item['status'] == 'PENDING_CONFIRMATION') return 'Pending confirmation';
    return switch (item['confirmationSource']) {
      'USER_REPORTED' => 'Recorded by you',
      'RECIPIENT_RECORDED' => 'Recorded by recipient',
      'PROVIDER_CONFIRMED' => 'Automatically verified',
      _ => 'Recipient confirmed',
    };
  }

  String _sourceLabel(Object? value) => switch (value) {
    'ORDER' => 'Supplier order',
    'BOUNTY_PAYMENT' => 'Bounty payment',
    'FORCED_REASSIGNMENT' => 'Chore compensation',
    'PENALTY' => 'Penalty',
    'HOUSEHOLD_PURCHASE' => 'Shared purchase',
    'OTHER' => 'Personal debt',
    _ => 'Debt',
  };

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
        backgroundColor: const Color(0xFFF8F7F9),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Back',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/houses/${widget.houseId}');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded, color: _muted),
                    ),
                    const Expanded(
                      child: Text(
                        'Payment History',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1ECFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Verified',
                        style: TextStyle(
                          color: _purple,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ref
                    .watch(paymentHistoryProvider(query))
                    .when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: _purple),
                      ),
                      error: (e, _) => SupplyFailure(
                        e,
                        () => ref.invalidate(paymentHistoryProvider(query)),
                      ),
                      data: (data) {
                        final items = (data['items'] as List? ?? [])
                            .cast<Map<dynamic, dynamic>>()
                            .toList();
                        items.sort((a, b) {
                          final at =
                              DateTime.tryParse('${a['recordedAt']}') ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          final bt =
                              DateTime.tryParse('${b['recordedAt']}') ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          return _newestFirst
                              ? bt.compareTo(at)
                              : at.compareTo(bt);
                        });
                        final moneyIn = (data['moneyIn'] as num? ?? 0)
                            .toDouble();
                        final moneyOut = (data['moneyOut'] as num? ?? 0)
                            .toDouble();
                        final net = moneyIn - moneyOut;
                        final totalCount = (data['totalCount'] as num? ?? 0)
                            .toInt();

                        return RefreshIndicator(
                          color: _purple,
                          onRefresh: () async {
                            ref.invalidate(paymentHistoryProvider(query));
                            await ref.read(
                              paymentHistoryProvider(query).future,
                            );
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 26),
                            children: [
                              _monthSelector(),
                              const SizedBox(height: 12),
                              _filters(moneyIn, moneyOut),
                              const SizedBox(height: 14),
                              _summaryCard(moneyIn, moneyOut, net),
                              const SizedBox(height: 19),
                              Row(
                                children: [
                                  const Text(
                                    'Transactions',
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    '$totalCount records',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => setState(
                                      () => _newestFirst = !_newestFirst,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _muted,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(
                                      Icons.swap_vert_rounded,
                                      size: 17,
                                    ),
                                    label: Text(
                                      _newestFirst ? 'Newest' : 'Oldest',
                                      style: const TextStyle(fontSize: 10.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              if (items.isEmpty)
                                _emptyState()
                              else
                                for (final item in items)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _transactionCard(context, item),
                                  ),
                              if (totalCount > 30) ...[
                                const SizedBox(height: 8),
                                _pagination(totalCount),
                              ],
                            ],
                          ),
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

  Widget _monthSelector() => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() {
            _month = DateTime(_month.year, _month.month - 1);
            _page = 1;
          }),
          icon: const Icon(Icons.chevron_left_rounded, color: _muted, size: 20),
        ),
        const Icon(Icons.calendar_month_rounded, color: _purple, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(_month),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() {
            _month = DateTime(_month.year, _month.month + 1);
            _page = 1;
          }),
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: _muted,
            size: 20,
          ),
        ),
      ],
    ),
  );

  Widget _filters(double moneyIn, double moneyOut) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _filterPill('All', 'ALL', null),
        const SizedBox(width: 7),
        _filterPill('Money in', 'IN', moneyIn, _green),
        const SizedBox(width: 7),
        _filterPill('Money out', 'OUT', moneyOut, _red),
      ],
    ),
  );

  Widget _filterPill(String label, String value, double? amount, [Color? dot]) {
    final selected = _direction == value;
    return Material(
      color: selected ? const Color(0xFFF0EBFF) : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? const Color(0xFFD8CCFF) : _line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => setState(() {
          _direction = value;
          _page = 1;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? _purple : _muted,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (amount != null) ...[
                const SizedBox(width: 5),
                Text(
                  '${amount >= 0 ? '+' : ''}${_compactMoney(amount)}',
                  style: TextStyle(
                    color: dot,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(double moneyIn, double moneyOut, double net) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Monthly summary',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              supplyMoney(moneyIn + moneyOut),
              style: const TextStyle(
                color: _muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              ' total',
              style: TextStyle(color: _muted, fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F3FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: _purple,
                size: 17,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Net cash flow',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${net >= 0 ? '+' : ''}${supplyMoney(net)}',
                style: TextStyle(
                  color: net >= 0 ? _green : _red,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _summaryMetric(
                'Money in',
                moneyIn,
                _green,
                Icons.south_west_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryMetric(
                'Money out',
                moneyOut,
                _red,
                Icons.north_east_rounded,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _summaryMetric(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color == _green
          ? const Color(0xFFEAF8F2)
          : const Color(0xFFFFF0F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: color == _green
            ? const Color(0xFFB9E8D3)
            : const Color(0xFFF4C6CF),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                supplyMoney(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _transactionCard(BuildContext context, Map<dynamic, dynamic> item) {
    final incoming = item['direction'] == 'IN';
    final color = incoming ? _green : _red;
    final recorded = DateTime.tryParse('${item['recordedAt']}');
    final source = item['source']?.toString() ?? '';
    final icon = source == 'ORDER'
        ? Icons.shopping_bag_outlined
        : incoming
        ? Icons.call_received_rounded
        : Icons.call_made_rounded;
    final title = source == 'ORDER'
        ? 'Supplier payment'
        : incoming
        ? 'Money in · ${_sourceLabel(source)}'
        : 'Money out · ${_sourceLabel(source)}';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          source == 'ORDER'
              ? '/houses/${widget.houseId}/orders/${item['sourceId']}'
              : '/houses/${widget.houseId}/account/debts/${item['sourceId']}',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: incoming
                      ? const Color(0xFFE7F8F1)
                      : const Color(0xFFFFEDF0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['counterparty']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${recorded == null ? '' : DateFormat('MMM d, yyyy').format(vietnamDay(recorded))} · ${_statusLabel(item)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${incoming ? '+' : '-'}${supplyMoney(item['amount'])}',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Details',
                    style: TextStyle(
                      color: _purple,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _line),
    ),
    child: const Text(
      'No transactions this month.',
      style: TextStyle(color: _muted, fontSize: 12),
    ),
  );

  Widget _pagination(int totalCount) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      TextButton(
        onPressed: _page <= 1 ? null : () => setState(() => _page--),
        child: const Text('← Previous'),
      ),
      Text(
        '$_page / ${(totalCount / 30).ceil()}',
        style: const TextStyle(
          color: _muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      TextButton(
        onPressed: _page * 30 >= totalCount
            ? null
            : () => setState(() => _page++),
        child: const Text('Next →'),
      ),
    ],
  );

  String _compactMoney(double amount) {
    final abs = amount.abs();
    if (abs >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}tr';
    if (abs >= 1000) return '${(amount / 1000).toStringAsFixed(0)}k';
    return amount.toStringAsFixed(0);
  }
}
