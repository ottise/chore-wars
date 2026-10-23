import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/gamification_models.dart';
import '../providers/gamification_providers.dart';

enum _ActivityFilter { all, earned, penalties, spent }

class KarmaHistoryScreen extends ConsumerStatefulWidget {
  const KarmaHistoryScreen({required this.houseId, super.key});
  final String houseId;
  @override
  ConsumerState<KarmaHistoryScreen> createState() => _KarmaHistoryScreenState();
}

class _KarmaHistoryScreenState extends ConsumerState<KarmaHistoryScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;
  @override
  Widget build(BuildContext context) {
    final history = ref.watch(karmaHistoryProvider(widget.houseId));
    final balance = ref.watch(karmaSummaryProvider(widget.houseId));
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Karma History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(karmaSummaryProvider(widget.houseId));
          ref.invalidate(karmaHistoryProvider(widget.houseId));
          await ref.read(karmaHistoryProvider(widget.houseId).future);
        },
        child: history.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(karmaHistoryProvider(widget.houseId)),
          ),
          data: (items) {
            final sorted = [...items]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final visible = sorted
                .where(
                  (item) => switch (_filter) {
                    _ActivityFilter.all => true,
                    _ActivityFilter.earned => item.amount > 0,
                    _ActivityFilter.penalties =>
                      item.type == KarmaTransactionType.penalty,
                    _ActivityFilter.spent =>
                      item.type == KarmaTransactionType.rewardRedeemed,
                  },
                )
                .toList();
            int total(bool Function(KarmaTransaction) test) =>
                items.where(test).fold(0, (sum, item) => sum + item.amount);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Balance',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        balance.when(
                          data: (value) => Text(
                            '${value.current} Karma',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          loading: () => const Text('Loading…'),
                          error: (_, _) => TextButton(
                            onPressed: () => ref.invalidate(
                              karmaSummaryProvider(widget.houseId),
                            ),
                            child: const Text('Retry Balance'),
                          ),
                        ),
                        const Divider(height: 28),
                        Row(
                          children: [
                            _Total(
                              label: 'Earned',
                              amount: total((item) => item.amount > 0),
                              color: AppTheme.green,
                            ),
                            _Total(
                              label: 'Penalties',
                              amount: total(
                                (item) =>
                                    item.type == KarmaTransactionType.penalty,
                              ),
                              color: colors.error,
                            ),
                            _Total(
                              label: 'Spent',
                              amount: total(
                                (item) =>
                                    item.type ==
                                    KarmaTransactionType.rewardRedeemed,
                              ),
                              color: colors.tertiary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in const {
                        _ActivityFilter.all: 'All',
                        _ActivityFilter.earned: 'Earned (+)',
                        _ActivityFilter.penalties: 'Penalties (-)',
                        _ActivityFilter.spent: 'Spent',
                      }.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            shape: const StadiumBorder(),
                            backgroundColor: colors.surfaceContainerLowest,
                            selectedColor: colors.primary,
                            labelStyle: TextStyle(
                              color: _filter == entry.key
                                  ? colors.onPrimary
                                  : colors.onSurfaceVariant,
                            ),
                            selected: _filter == entry.key,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _filter = entry.key),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'No Karma activity in this category.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                for (final item in visible)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  (item.amount >= 0
                                          ? AppTheme.green
                                          : colors.error)
                                      .withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              item.amount >= 0
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: item.amount >= 0
                                  ? AppTheme.green
                                  : colors.error,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat.yMMMd('en_US')
                                      .add_jm()
                                      .format(item.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.amount > 0 ? '+' : ''}${item.amount} Karma',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: item.amount >= 0
                                  ? AppTheme.green
                                  : colors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final int amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 6),
          Text(
            '${amount > 0 ? '+' : ''}$amount',
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
