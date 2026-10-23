import '../widgets/achievement_share_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/gamification_models.dart';
import '../providers/gamification_providers.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({required this.houseId, super.key});
  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider(houseId));
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'House Achievements',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(achievementsProvider(houseId));
          await ref.read(achievementsProvider(houseId).future);
        },
        child: achievements.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(achievementsProvider(houseId)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyView(
                icon: Icons.workspace_premium_outlined,
                title: 'No achievements yet',
                message: 'House achievements will show up here.',
              );
            }
            final unlocked = items.where((item) => item.isUnlocked).length;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: _ProgressHeader(
                      unlocked: unlocked,
                      total: items.length,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      mainAxisExtent:
                          220 + MediaQuery.textScalerOf(context).scale(40),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _AchievementCard(
                      item: items[index],
                      onTap: items[index].isUnlocked
                          ? () => showDialog<void>(
                              context: context,
                              builder: (context) => AchievementShareCard(
                                achievement: items[index],
                              ),
                            )
                          : null,
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

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.unlocked, required this.total});
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) => Card(
    color: AppTheme.purple,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppTheme.yellow,
            size: 42,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unlocked of $total Unlocked',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : unlocked / total,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 8),
                Text(
                  '${total == 0 ? 0 : (unlocked / total * 100).round()}% unlocked · Keep completing household tasks',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.item, this.onTap});
  final Achievement item;
  final VoidCallback? onTap;
  IconData get _icon => switch (item.conditionType) {
    1 => Icons.local_fire_department_rounded,
    2 => Icons.bolt_rounded,
    3 => Icons.volunteer_activism_rounded,
    _ => Icons.cleaning_services_rounded,
  };
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: item.isUnlocked
          ? colors.surfaceContainerLowest
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: item.isUnlocked
              ? colors.primaryFixedDim
              : colors.outlineVariant.withValues(alpha: .35),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.isUnlocked
                          ? colors.primaryFixed
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.isUnlocked ? _icon : Icons.lock_outline_rounded,
                      size: 22,
                      color: item.isUnlocked
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.isUnlocked ? 'Done' : 'Locked',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        color: item.isUnlocked
                            ? AppTheme.green
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Divider(color: colors.outlineVariant.withValues(alpha: .4)),
              Text(
                item.isUnlocked
                    ? 'Achievement unlocked'
                    : 'Target: ${item.threshold}',
                style: TextStyle(
                  fontSize: 10,
                  color: item.isUnlocked
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
