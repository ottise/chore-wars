import 'dart:math' as math;

import '../screens/member_schedule_detail_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/house_calendar_models.dart';
import '../providers/household_summary_provider.dart';
import '../../../supplies/presentation/widgets/supplies_ui.dart';

class HouseholdSummarySection extends ConsumerStatefulWidget {
  const HouseholdSummarySection({
    required this.houseId,
    required this.seasonId,
    required this.section,
    this.seasonName,
    this.occurrences = const [],
    this.scheduleHeader,
    this.scheduleFooter,
    super.key,
  });
  final String houseId, seasonId;
  final int section;
  final String? seasonName;
  final List<dynamic> occurrences;
  final Widget? scheduleHeader;
  final Widget? scheduleFooter;

  @override
  ConsumerState<HouseholdSummarySection> createState() =>
      _HouseholdSummarySectionState();
}

class _HouseholdSummarySectionState
    extends ConsumerState<HouseholdSummarySection> {
  late DateTime _month = DateTime(
    vietnamDay(DateTime.now()).year,
    vietnamDay(DateTime.now()).month,
  );
  final bool _seasonOnly = false;

  static const _purple = Color(0xFF7C4DFF);
  static const _purpleSoft = Color(0xFFEDE9FE);
  static const _red = Color(0xFFDC2626);
  static const _lavender = Color(0xFFC4B5FD);

  static const _segmentColors = [
    Color(0xFF6D28D9),
    Color(0xFF8B5CF6),
    Color(0xFFC4B5FD),
    Color(0xFFF59E0B),
    Color(0xFFCBD5E1),
  ];

  static const _avatarBgColors = [
    Color(0xFFEDE9FE),
    Color(0xFFFEF3C7),
    Color(0xFFE0F2FE),
    Color(0xFFFFEDD5),
    Color(0xFFDCFCE7),
  ];

  static const _avatarTextColors = [
    Color(0xFF6D28D9),
    Color(0xFFB45309),
    Color(0xFF0369A1),
    Color(0xFFC2410C),
    Color(0xFF15803D),
  ];

  @override
  Widget build(BuildContext context) {
    final q = (
      house: widget.houseId,
      from: DateFormat('yyyy-MM-dd').format(_month),
      to: DateFormat('yyyy-MM-dd')
          .format(DateTime(_month.year, _month.month + 1, 0)),
      season: _seasonOnly ? widget.seasonId : null,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFEDEAF6)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: _purple,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          DateFormat('MMMM yyyy')
                              .format(_month)
                              .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ref
              .watch(householdSummaryProvider(q))
              .when(
                loading: () =>
                    widget.section != 1 &&
                        (widget.scheduleHeader != null ||
                            widget.scheduleFooter != null)
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [_buildUnifiedOverview(const {}, q)],
                      )
                    : const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    widget.section != 1 &&
                        (widget.scheduleHeader != null ||
                            widget.scheduleFooter != null)
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [_buildUnifiedOverview(const {}, q)],
                      )
                    : SupplyFailure(
                        e,
                        () => ref.invalidate(householdSummaryProvider(q)),
                      ),
                data: (data) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(householdSummaryProvider(q));
                    await ref.read(householdSummaryProvider(q).future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (widget.section == 1)
                        _buildSpendingSection(data)
                      else
                        _buildUnifiedOverview(data, q),
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSpendingSection(Map<String, dynamic> data) {
    final externalAmount = (data['externalPayments'] as num? ?? 0).round();
    final formattedHeroAmount = NumberFormat('#,###').format(externalAmount);
    final paidOrders = (data['paidOrderCount'] as num? ?? 0).toInt();
    final unpaidOrders = (data['unpaidOrderCount'] as num? ?? 0).toInt();
    final orders = data['orders'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7C4DFF), Color(0xFF6366F1)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TOTAL EXTERNAL SPENDING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'This Month',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      formattedHeroAmount,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'VND',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$paidOrders ${paidOrders == 1 ? 'transaction' : 'transactions'} recorded across household groceries and essentials',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SpendingMetricTile(
          icon: Icons.credit_card_rounded,
          iconBg: _purpleSoft,
          iconColor: _purple,
          title: 'Recorded external payments',
          subtitle: 'Paid to third-party suppliers',
          value: supplyMoney(data['externalPayments']),
        ),
        const SizedBox(height: 10),
        _SpendingMetricTile(
          icon: Icons.check_circle_outline_rounded,
          iconBg: const Color(0xFFDCFCE7),
          iconColor: const Color(0xFF16A34A),
          title: 'Paid orders',
          badgeText: 'Settled',
          subtitle: 'Fulfilled group orders',
          value: '$paidOrders',
        ),
        const SizedBox(height: 10),
        _SpendingMetricTile(
          icon: Icons.access_time_rounded,
          iconBg: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          title: 'Unpaid orders',
          subtitle: 'Created this month',
          value: '$unpaidOrders',
        ),
        const SizedBox(height: 10),
        _SpendingMetricTile(
          icon: Icons.swap_horiz_rounded,
          iconBg: _purpleSoft,
          iconColor: _purple,
          title: 'Internal transfers',
          subtitle: 'Between housemates',
          value: supplyMoney(data['internalTransfers']),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Color(0xFFD97706),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Transfers between members are not counted again as household spending. User-recorded payments are not bank verification.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (orders.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFEDEAF6)),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: Text(
                    '${order['supplier']} · ${supplyMoney(order['amount'])}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Paid by ${order['payer']} · ${order['confirmationSource'] == 'USER_REPORTED' ? 'User recorded' : 'Provider confirmed'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/houses/${widget.houseId}/orders/${order['id']}',
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildUnifiedOverview(
    Map<String, dynamic> data,
    ({String house, String from, String to, String? season}) q,
  ) {
    final assigned = (data['assigned'] as num? ?? 0).toInt();
    final completed = (data['completed'] as num? ?? 0).toInt();
    final overdue = (data['overdue'] as num? ?? 0).toInt();
    final upcoming = (data['upcoming'] as num? ?? 0).toInt();
    final members = (data['members'] as List? ?? [])
        .cast<Map<dynamic, dynamic>>();
    final rateRound = assigned > 0 ? (completed * 100 / assigned).round() : 0;
    final equilibrium = _computeEquilibriumScore(members);
    final weekdayMinutes = _computeWeekdayMinutes(members);
    final maxWeekdayMin = weekdayMinutes.fold<int>(0, math.max);
    var peakDayIndex = 2;
    if (maxWeekdayMin > 0) {
      peakDayIndex = weekdayMinutes.indexOf(maxWeekdayMin);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.scheduleHeader != null) ...[
          widget.scheduleHeader!,
          const SizedBox(height: 14),
        ],
        // 1. Top Donut + 2x2 KPI Grid Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEDEAF6)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: CustomPaint(
                  painter: _SummaryDonutPainter(
                    completed: completed,
                    overdue: overdue,
                    upcoming: upcoming,
                    total: assigned,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$rateRound%',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          assigned == 0
                              ? 'Not available'
                              : '$completed/$assigned',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MiniKpiCard(
                            bgColor: const Color(0xFFF5F3FF),
                            dotColor: _purple,
                            label: 'Done',
                            labelColor: const Color(0xFF475569),
                            value: '$completed',
                            valueColor: const Color(0xFF5B21B6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniKpiCard(
                            bgColor: const Color(0xFFFEF2F2),
                            dotColor: _red,
                            label: 'Overdue',
                            labelColor: const Color(0xFF991B1B),
                            value: '$overdue',
                            valueColor: _red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniKpiCard(
                            bgColor: const Color(0xFFF8FAFC),
                            dotColor: _lavender,
                            label: 'Upcoming',
                            labelColor: const Color(0xFF475569),
                            value: '$upcoming',
                            valueColor: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniKpiCard(
                            bgColor: const Color(0xFFFFFBEB),
                            dotColor: const Color(0xFFD97706),
                            label: 'Equilibrium',
                            labelColor: const Color(0xFFB45309),
                            value: '$equilibrium%',
                            valueColor: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (assigned == 0) ...[
          const SizedBox(height: 8),
          const Text(
            'No chores yet for this period.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
        const SizedBox(height: 14),

        // 2. Weekly Velocity Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEDEAF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    size: 18,
                    color: _purple,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'WEEKLY VELOCITY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _purpleSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Min / Day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _purple,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _VelocityBarColumn(
                          dayLetter: const [
                            'M',
                            'T',
                            'W',
                            'T',
                            'F',
                            'S',
                            'S',
                          ][i],
                          minutes: weekdayMinutes[i],
                          maxMinutes: math.max(maxWeekdayMin, 60),
                          isPeak: maxWeekdayMin > 0 && i == peakDayIndex,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Equilibrium Ratio Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEDEAF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.pie_chart_outline_rounded,
                    size: 18,
                    color: _purple,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'EQUILIBRIUM RATIO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      equilibrium >= 75 ? 'Equitable' : 'Rebalance',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: _buildEquilibriumSegments(members),
                  ),
                ),
              ),
              if (members.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildEquilibriumLegend(members),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 4. Members List Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MEMBERS (${members.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: Color(0xFF64748B),
              ),
            ),
            if (widget.seasonName != null && widget.seasonName!.isNotEmpty)
              Text(
                widget.seasonName!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _purple,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No member data yet.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ),
        for (var idx = 0; idx < members.length; idx++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemberOverviewCard(
              member: members[idx],
              index: idx,
              avatarBg: _avatarBgColors[idx % _avatarBgColors.length],
              avatarTextColor:
                  _avatarTextColors[idx % _avatarTextColors.length],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MemberScheduleDetailScreen(
                    houseId: widget.houseId,
                    userId: members[idx]['userId'].toString(),
                    name: members[idx]['name'].toString(),
                    from: q.from,
                    to: q.to,
                    seasonId: q.season,
                  ),
                ),
              ),
            ),
          ),
        if (widget.scheduleFooter != null) ...[
          const SizedBox(height: 12),
          widget.scheduleFooter!,
        ],
      ],
    );
  }

  int _computeEquilibriumScore(List<Map<dynamic, dynamic>> members) {
    if (members.length < 2) return 100;
    final loads = members
        .map(
          (m) => math.max(
            1,
            (m['plannedMinutes'] as num? ?? (m['assigned'] as num? ?? 0) * 15)
                .toInt(),
          ),
        )
        .toList();
    final total = loads.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return 100;
    final avg = total / loads.length;
    final maxDiff = loads
        .map((x) => (x - avg).abs())
        .fold<double>(0, math.max);
    final score = (100 - (maxDiff / total * 100)).round().clamp(50, 100);
    return score;
  }

  List<int> _computeWeekdayMinutes(List<Map<dynamic, dynamic>> members) {
    final buckets = List<int>.filled(7, 0);
    if (widget.occurrences.isNotEmpty) {
      for (final raw in widget.occurrences) {
        if (raw is! Map) continue;
        final dueStr = raw['dueDate']?.toString() ?? raw['dueAt']?.toString();
        if (dueStr == null) continue;
        final parsed = DateTime.tryParse(dueStr);
        if (parsed == null) continue;
        final local = vietnamDay(parsed);
        final dayIdx = (local.weekday - 1).clamp(0, 6);
        final mins =
            (raw['snapshotMinutes'] as num? ??
                    raw['estimatedMinutes'] as num? ??
                    30)
                .toInt();
        buckets[dayIdx] += mins;
      }
      if (buckets.any((m) => m > 0)) return buckets;
    }
    final totalPlanned = members.fold<int>(
      0,
      (sum, m) => sum + (m['plannedMinutes'] as num? ?? 0).toInt(),
    );
    if (totalPlanned <= 0) return buckets;
    final weights = const [2, 3, 4, 2, 1, 2, 1];
    final weightSum = weights.fold<int>(0, (a, b) => a + b);
    for (var i = 0; i < 7; i++) {
      buckets[i] = ((totalPlanned * weights[i]) / weightSum).round();
    }
    return buckets;
  }

  List<Widget> _buildEquilibriumSegments(List<Map<dynamic, dynamic>> members) {
    if (members.isEmpty) {
      return [
        Expanded(
          child: Container(color: const Color(0xFFE2E8F0)),
        ),
      ];
    }
    final weights = members
        .map(
          (m) => math.max(
            1,
            (m['plannedMinutes'] as num? ?? (m['assigned'] as num? ?? 1) * 15)
                .toInt(),
          ),
        )
        .toList();
    return [
      for (var i = 0; i < members.length; i++) ...[
        if (i > 0) const SizedBox(width: 2),
        Expanded(
          flex: weights[i],
          child: Container(
            color: _segmentColors[i % _segmentColors.length],
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildEquilibriumLegend(List<Map<dynamic, dynamic>> members) {
    final weights = members
        .map(
          (m) => math.max(
            1,
            (m['plannedMinutes'] as num? ?? (m['assigned'] as num? ?? 1) * 15)
                .toInt(),
          ),
        )
        .toList();
    final total = math.max(1, weights.fold<int>(0, (a, b) => a + b));
    return [
      for (var i = 0; i < members.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _segmentColors[i % _segmentColors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${members[i]['name']} ${((weights[i] * 100) / total).round()}%',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _SummaryDonutPainter extends CustomPainter {
  _SummaryDonutPainter({
    required this.completed,
    required this.overdue,
    required this.upcoming,
    required this.total,
  });

  final int completed;
  final int overdue;
  final int upcoming;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.5;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2 + 2);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFF1F5F9);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, basePaint);

    final sum = completed + overdue + upcoming;
    final denom = math.max(total, sum);
    if (denom <= 0) return;

    var startAngle = -math.pi / 2;
    final segments = [
      (completed, const Color(0xFF7C4DFF)),
      (overdue, const Color(0xFFB91C1C)),
      (upcoming, const Color(0xFFC4B5FD)),
    ];
    for (final seg in segments) {
      if (seg.$1 <= 0) continue;
      final sweep = (seg.$1 / denom) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = seg.$2;
      canvas.drawArc(arcRect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _SummaryDonutPainter oldDelegate) =>
      oldDelegate.completed != completed ||
      oldDelegate.overdue != overdue ||
      oldDelegate.upcoming != upcoming ||
      oldDelegate.total != total;
}

class _MiniKpiCard extends StatelessWidget {
  const _MiniKpiCard({
    required this.bgColor,
    required this.dotColor,
    required this.label,
    required this.labelColor,
    required this.value,
    required this.valueColor,
  });

  final Color bgColor;
  final Color dotColor;
  final String label;
  final Color labelColor;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _VelocityBarColumn extends StatelessWidget {
  const _VelocityBarColumn({
    required this.dayLetter,
    required this.minutes,
    required this.maxMinutes,
    required this.isPeak,
  });

  final String dayLetter;
  final int minutes;
  final int maxMinutes;
  final bool isPeak;

  @override
  Widget build(BuildContext context) {
    final ratio = maxMinutes > 0
        ? (minutes / maxMinutes).clamp(0.14, 1.0)
        : 0.14;
    final barHeight = (74 * ratio).roundToDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: isPeak
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Text(
            '${minutes}m',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
              color: isPeak
                  ? const Color(0xFF7C4DFF)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ),
        if (isPeak) ...[
          const SizedBox(height: 2),
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF7C4DFF),
              shape: BoxShape.circle,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Container(
          width: 16,
          height: barHeight,
          decoration: BoxDecoration(
            color: isPeak
                ? const Color(0xFF7C4DFF)
                : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          dayLetter,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
            color: isPeak
                ? const Color(0xFF7C4DFF)
                : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class _MemberOverviewCard extends StatelessWidget {
  const _MemberOverviewCard({
    required this.member,
    required this.index,
    required this.avatarBg,
    required this.avatarTextColor,
    required this.onTap,
  });

  final Map<dynamic, dynamic> member;
  final int index;
  final Color avatarBg;
  final Color avatarTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (member['name'] ?? 'Member').toString();
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    final assigned = (member['assigned'] as num? ?? 0).toInt();
    final completed = (member['completed'] as num? ?? 0).toInt();
    final overdue = (member['overdue'] as num? ?? 0).toInt();
    final remaining = (member['remaining'] as num? ?? 0).toInt();
    final plannedMinutes = (member['plannedMinutes'] as num? ?? 0).toInt();
    final progress = assigned > 0
        ? (completed / assigned).clamp(0.08, 1.0).toDouble()
        : 0.08;

    final (
      String badgeText,
      Color badgeBg,
      Color badgeFg,
      Color barColor,
    ) = overdue > 0
        ? (
            '$overdue Overdue',
            const Color(0xFFFEE2E2),
            const Color(0xFFDC2626),
            const Color(0xFFEF4444),
          )
        : completed > 0
        ? (
            'On Track',
            const Color(0xFFEDE9FE),
            const Color(0xFF7C4DFF),
            const Color(0xFF7C4DFF),
          )
        : remaining >= 2
        ? (
            '$remaining Today',
            const Color(0xFFFEF3C7),
            const Color(0xFFB45309),
            const Color(0xFFF59E0B),
          )
        : (
            'Pending',
            const Color(0xFFF1F5F9),
            const Color(0xFF475569),
            const Color(0xFFCBD5E1),
          );

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEDEAF6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: avatarTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 84,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          color: barColor,
                          backgroundColor: const Color(0xFFF1F5F9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$completed/$assigned',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${plannedMinutes}m',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpendingMetricTile extends StatelessWidget {
  const _SpendingMetricTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    this.badgeText,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEAF6)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeText!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
