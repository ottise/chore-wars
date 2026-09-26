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
      appBar: AppBar(title: const Text('Achievements')),
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.86,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _AchievementCard(item: items[index]),
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
                  '$unlocked of $total unlocked',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : unlocked / total,
                  color: AppTheme.yellow,
                  backgroundColor: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
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
  const _AchievementCard({required this.item});
  final Achievement item;

  IconData get _icon => switch (item.conditionType) {
    1 => Icons.local_fire_department_rounded,
    2 => Icons.bolt_rounded,
    3 => Icons.volunteer_activism_rounded,
    _ => Icons.cleaning_services_rounded,
  };

  @override
  Widget build(BuildContext context) => Card(
    color: item.isUnlocked
        ? Theme.of(context).colorScheme.surface
        : Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: item.isUnlocked
                ? AppTheme.yellow.withValues(alpha: 0.35)
                : Colors.black12,
            child: Icon(
              item.isUnlocked ? _icon : Icons.lock_outline_rounded,
              color: item.isUnlocked ? const Color(0xFF7A5700) : AppTheme.muted,
            ),
          ),
          const Spacer(),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            item.isUnlocked ? 'Unlocked' : item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: item.isUnlocked ? AppTheme.green : AppTheme.muted,
              fontWeight: item.isUnlocked ? FontWeight.w800 : FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}
