import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_page_frame.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/gamification_models.dart';
import '../providers/gamification_providers.dart';
import '../../../../core/utils/api_error_message.dart';

class SeasonRewardScreen extends ConsumerStatefulWidget {
  const SeasonRewardScreen({
    required this.houseId,
    required this.seasonId,
    super.key,
  });
  final String houseId;
  final String seasonId;

  @override
  ConsumerState<SeasonRewardScreen> createState() => _SeasonRewardScreenState();
}

class _SeasonRewardScreenState extends ConsumerState<SeasonRewardScreen> {
  String? _busyId;

  @override
  Widget build(BuildContext context) => AppPageFrame(builder: _buildScreen);

  Widget _buildScreen(BuildContext context) {
    final key = (houseId: widget.houseId, seasonId: widget.seasonId);
    final rewards = ref.watch(seasonRewardsProvider(key));
    return Scaffold(
      appBar: AppPageBar(title: 'Season Rewards'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(seasonRewardsProvider(key));
          await ref.read(seasonRewardsProvider(key).future);
        },
        child: rewards.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(seasonRewardsProvider(key)),
          ),
          data: (items) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const Text(
                'Final rank rewards are distributed at the end of each season.',
                style: TextStyle(
                  color: AppTheme.muted,
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              Card(
                margin: EdgeInsets.zero,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.primaryFixed,
                        Theme.of(context).colorScheme.surfaceContainerLowest,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLowest
                              .withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.card_giftcard_outlined,
                          size: 42,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Season Prize Pool',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Leaderboard rewards',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(
                      '/houses/${widget.houseId}/seasons/${widget.seasonId}/leaderboard',
                    ),
                    child: const Text('View Ranks'),
                  ),
                ],
              ),
              if (items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No rewards yet. Final rank rewards appear after the season ends.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              for (final reward in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RewardCard(
                    reward: reward,
                    busy: _busyId == reward.redemptionId,
                    onClaim: reward.redemptionId == null
                        ? null
                        : () => _claim(reward, key),
                    onUse: reward.redemptionId == null
                        ? null
                        : () => context.push(
                            '/houses/${widget.houseId}/seasons/${widget.seasonId}/chore-pass/${reward.redemptionId}',
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claim(SeasonReward reward, SeasonKey key) async {
    setState(() => _busyId = reward.redemptionId);
    try {
      await ref
          .read(gamificationRepositoryProvider)
          .claimReward(widget.houseId, reward.redemptionId!);
      ref.invalidate(seasonRewardsProvider(key));
      if (mounted) showAppMessage(context, 'Reward claimed');
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.busy,
    required this.onClaim,
    required this.onUse,
  });
  final SeasonReward reward;
  final bool busy;
  final VoidCallback? onClaim;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    reward.isChorePass
                        ? Icons.shield_outlined
                        : Icons.emoji_events_outlined,
                    color: colors.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.status.label,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        reward.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 16),
                      ),
                      if (reward.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          reward.description,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (reward.claimDeadline != null) ...[
              const SizedBox(height: 16),
              _DeadlineRow(label: 'Claim by', date: reward.claimDeadline!),
            ],
            if (reward.usageDeadline != null) ...[
              const SizedBox(height: 10),
              _DeadlineRow(label: 'Use by', date: reward.usageDeadline!),
            ],
            if (reward.status == RedemptionStatus.unclaimed &&
                onClaim != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : onClaim,
                child: Text(busy ? 'Claiming…' : 'Claim Reward'),
              ),
            ] else if (reward.status == RedemptionStatus.claimed &&
                reward.isChorePass &&
                onUse != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onUse,
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('Use Chore Pass'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.label, required this.date});
  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.schedule_outlined, size: 18),
      const SizedBox(width: 8),
      Text(label),
      const Spacer(),
      Flexible(
        flex: 3,
        child: Text(
          DateFormat.yMMMd('en_US').add_jm().format(date),
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
