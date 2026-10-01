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
  Widget build(BuildContext context) {
    final key = (houseId: widget.houseId, seasonId: widget.seasonId);
    final rewards = ref.watch(seasonRewardsProvider(key));
    return Scaffold(
      appBar: AppBar(title: const Text('Season reward')),
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
          data: (items) => items.isEmpty
              ? const EmptyView(
                  icon: Icons.card_giftcard_rounded,
                  title: 'No reward for this season',
                  message: 'Final rank rewards appear after the season ends.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final reward = items[index];
                    return _RewardCard(
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
                    );
                  },
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
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Container(
          width: double.infinity,
          color: AppTheme.purple,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 54,
                color: AppTheme.yellow,
              ),
              const SizedBox(height: 12),
              Text(
                reward.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                reward.status.label,
                style: const TextStyle(
                  color: Color(0xFFE5E1FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (reward.description.isNotEmpty)
                Text(reward.description, textAlign: TextAlign.center),
              if (reward.claimDeadline != null) ...[
                const SizedBox(height: 16),
                _DeadlineRow(label: 'Claim by', date: reward.claimDeadline!),
              ],
              if (reward.usageDeadline != null) ...[
                const SizedBox(height: 10),
                _DeadlineRow(label: 'Use by', date: reward.usageDeadline!),
              ],
              const SizedBox(height: 20),
              if (reward.status == RedemptionStatus.unclaimed)
                ElevatedButton(
                  onPressed: busy ? null : onClaim,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Claim reward'),
                )
              else if (reward.status == RedemptionStatus.claimed &&
                  reward.isChorePass)
                ElevatedButton.icon(
                  onPressed: onUse,
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('Use chore pass'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.label, required this.date});
  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.schedule_rounded, size: 18),
      const SizedBox(width: 8),
      Text(label),
      const Spacer(),
      Text(
        DateFormat('MMM d, h:mm a').format(date),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ],
  );
}
