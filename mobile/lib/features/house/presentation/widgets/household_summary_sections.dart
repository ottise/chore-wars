import '../screens/member_schedule_detail_screen.dart';
import '../../../../core/widgets/member_avatar.dart';

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
    super.key,
  });
  final String houseId, seasonId;
  final int section;
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
  bool _seasonOnly = false;
  @override
  Widget build(BuildContext context) {
    final q = (
      house: widget.houseId,
      from: DateFormat('yyyy-MM-dd').format(_month),
      to: DateFormat('yyyy-MM-dd')
          .format(DateTime(_month.year, _month.month + 1, 0)),
      season: _seasonOnly ? widget.seasonId : null,
    );
    Widget metric(String title, Object value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SupplySurface(
        child: Row(
          children: [
            Expanded(child: Text(title)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$value',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
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
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (widget.section != 1)
          SwitchListTile(
            title: const Text('Selected season only'),
            value: _seasonOnly,
            onChanged: (v) => setState(() => _seasonOnly = v),
          ),
        Expanded(
          child: ref
              .watch(householdSummaryProvider(q))
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => SupplyFailure(
                  e,
                  () => ref.invalidate(householdSummaryProvider(q)),
                ),
                data: (data) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(householdSummaryProvider(q));
                    await ref.read(householdSummaryProvider(q).future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (widget.section == 1) ...[
                        metric(
                          'Recorded external payments',
                          supplyMoney(data['externalPayments']),
                        ),
                        metric('Paid orders', data['paidOrderCount'] ?? 0),
                        metric(
                          'Unpaid orders created this month',
                          data['unpaidOrderCount'] ?? 0,
                        ),
                        metric(
                          'Internal transfers',
                          supplyMoney(data['internalTransfers']),
                        ),
                        const Text(
                          'Transfers between members are not counted again as household spending. User-recorded payments are not bank verification.',
                        ),
                        const SizedBox(height: 16),
                        if ((data['orders'] as List? ?? []).isEmpty)
                          const Text(
                            'No recorded external payments for this period.',
                          ),
                        for (final order in data['orders'] as List? ?? [])
                          ListTile(
                            title: Text(
                              '${order['supplier']} · ${supplyMoney(order['amount'])}',
                            ),
                            subtitle: Text(
                              'Paid by ${order['payer']} · ${order['confirmationSource'] == 'USER_REPORTED' ? 'User recorded' : 'Provider confirmed'}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '/houses/${widget.houseId}/orders/${order['id']}',
                            ),
                          ),
                      ],
                      if (widget.section == 2) ...[
                        for (final entry in [
                          ('Completed', data['completed'] ?? 0),
                          ('Overdue', data['overdue'] ?? 0),
                          ('Upcoming', data['upcoming'] ?? 0),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${entry.$1}: ${entry.$2}'),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: (data['assigned'] as num? ?? 0) > 0
                                      ? ((entry.$2 as num) /
                                                (data['assigned'] as num))
                                            .clamp(0.0, 1.0)
                                            .toDouble()
                                      : 0,
                                  minHeight: 8,
                                ),
                              ],
                            ),
                          ),
                        if ((data['assigned'] as num? ?? 0) == 0)
                          const Text('No chores yet for this period.'),
                        metric(
                          'Completed / scheduled',
                          '${data['completed']} / ${data['assigned']}',
                        ),
                        metric(
                          'Completion rate',
                          (data['assigned'] as num? ?? 0) == 0
                              ? 'Not available'
                              : '${((data['completed'] as num) * 100 / (data['assigned'] as num)).round()}%',
                        ),
                        metric(
                          'On time / known completion times',
                          (data['completionTimingKnown'] as num? ?? 0) == 0
                              ? 'No recorded times'
                              : '${data['onTime']} / ${data['completionTimingKnown']}',
                        ),
                        metric('Overdue', data['overdue'] ?? 0),
                        metric('Upcoming', data['upcoming'] ?? 0),
                        metric('Skipped (excluded)', data['skipped'] ?? 0),
                        const Text(
                          'Based on chore deadlines in published schedules for the selected period. Skipped chores are excluded. Review draft assignments in Schedule.',
                        ),
                        TextButton(
                          onPressed: () =>
                              context.go('/houses/${widget.houseId}'),
                          child: const Text('Open household calendar'),
                        ),
                      ],
                      if (widget.section == 3) ...[
                        const Text(
                          'Planned minutes describe assigned workload, not actual time spent. Completed chores are credited only to their recorded finisher.',
                        ),
                        const SizedBox(height: 16),
                        if ((data['completionAuthorUnknown'] as num? ?? 0) > 0)
                          Text(
                            '${data['completionAuthorUnknown']} older completions have no recorded finisher and are not attributed to a member.',
                          ),
                        if ((data['members'] as List? ?? []).isEmpty)
                          const Text('No member data yet.'),
                        for (final member in data['members'] as List? ?? [])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SupplySurface(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      MemberAvatar(
                                        houseId: widget.houseId,
                                        userId: member['userId'],
                                        name: member['name'],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          member['name'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Assigned: ${member['assigned']} · Completed: ${member['completed']}',
                                  ),
                                  Text(
                                    'Planned: ${member['plannedMinutes']} min',
                                  ),
                                  Text(
                                    'Remaining: ${member['remaining']} · Overdue: ${member['overdue']}',
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            MemberScheduleDetailScreen(
                                              houseId: widget.houseId,
                                              userId: member['userId'],
                                              name: member['name'],
                                              from: q.from,
                                              to: q.to,
                                              seasonId: q.season,
                                            ),
                                      ),
                                    ),
                                    child: const Text(
                                      'View member schedule details',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }
}
