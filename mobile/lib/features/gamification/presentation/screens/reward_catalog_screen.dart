import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../providers/custom_reward_providers.dart';
import '../providers/gamification_providers.dart';
import 'reward_form_screen.dart';

class RewardCatalogScreen extends ConsumerStatefulWidget {
  final String houseId;
  const RewardCatalogScreen({super.key, required this.houseId});
  @override
  ConsumerState<RewardCatalogScreen> createState() =>
      _RewardCatalogScreenState();
}

class _RewardCatalogScreenState extends ConsumerState<RewardCatalogScreen> {
  String? _busy;
  final Map<String, String> _requestIds = {};
  Future<void> _redeem(String id) async {
    setState(() => _busy = id);
    try {
      await ref
          .read(customRewardRepositoryProvider)
          .redeem(
            widget.houseId,
            id,
            _requestIds.putIfAbsent(id, () => const Uuid().v4()),
          );
      _requestIds.remove(id);
      ref.invalidate(customRewardsProvider(widget.houseId));
      ref.invalidate(gamificationRepositoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reward redeemed. Karma has been deducted.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final balance = ref.watch(karmaSummaryProvider(widget.houseId));
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Household Rewards',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ref
          .watch(customRewardsProvider(widget.houseId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: TextButton(
                onPressed: () =>
                    ref.invalidate(customRewardsProvider(widget.houseId)),
                child: Text('${apiErrorMessage(error)} · Retry'),
              ),
            ),
            data: (items) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(customRewardsProvider(widget.houseId));
                ref.invalidate(karmaSummaryProvider(widget.houseId));
                await ref.read(customRewardsProvider(widget.houseId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.primaryContainer],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Balance',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              balance.when(
                                data: (value) => Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: '${value.current}'),
                                      const TextSpan(
                                        text: ' Karma',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                loading: () => const Text(
                                  'Loading…',
                                  style: TextStyle(color: Colors.white),
                                ),
                                error: (_, _) => TextButton(
                                  onPressed: () => ref.invalidate(
                                    karmaSummaryProvider(widget.houseId),
                                  ),
                                  child: const Text(
                                    'Retry Balance',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push(
                            '/houses/${widget.houseId}/karma/history',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: .16,
                            ),
                          ),
                          icon: const Icon(Icons.history_rounded, size: 16),
                          label: const Text('History'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Household rewards (${items.where((item) => item.enabled).length} active)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use your earned Karma for household rewards.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No rewards yet. Create one for your household.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  for (final item in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.primaryFixed,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.card_giftcard_outlined,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (item.description.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          item.description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.4,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        item.enabled
                                            ? 'Available'
                                            : 'Unavailable',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: item.enabled
                                              ? colors.primary
                                              : colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit reward',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  onPressed: _busy != null
                                      ? null
                                      : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => RewardFormScreen(
                                              houseId: widget.houseId,
                                              reward: item,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            const Divider(height: 28),
                            Row(
                              children: [
                                Icon(
                                  Icons.stars_rounded,
                                  size: 18,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${item.cost} Karma',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                FilledButton(
                                  onPressed: !item.enabled || _busy != null
                                      ? null
                                      : () => _redeem(item.id),
                                  child: Text(
                                    _busy == item.id
                                        ? 'Claiming…'
                                        : 'Claim Perk',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy != null
                        ? null
                        : () => context.push(
                            '/houses/${widget.houseId}/rewards/new',
                          ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Household Reward'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
