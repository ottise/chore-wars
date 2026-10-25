import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_page_frame.dart';
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
  Widget build(BuildContext context, WidgetRef ref) =>
      AppPageFrame(builder: (context) => _buildScreen(context, ref));

  Widget _buildScreen(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider(houseId));
    return Scaffold(
      appBar: AppPageBar(title: 'House Achievements'),
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: _ProgressHeader(
                      unlocked: unlocked,
                      total: items.length,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      mainAxisExtent:
                          220 +
                          MediaQuery.textScalerOf(context).scale(180) -
                          180,
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ratio = total == 0 ? 0.0 : unlocked / total;
    return Card(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primaryContainer, colors.primary],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$unlocked of $total Unlocked',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${(ratio * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Keep completing household tasks to unlock achievements',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.item, this.onTap});
  final Achievement item;
  final VoidCallback? onTap;
  IconData get _icon => switch (item.conditionType) {
    1 => Icons.local_fire_department_outlined,
    2 => Icons.bolt_outlined,
    3 => Icons.volunteer_activism_outlined,
    _ => Icons.cleaning_services_outlined,
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
        borderRadius: BorderRadius.circular(16),
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
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.isUnlocked
                              ? const Color(0xFFEAFBF4)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.isUnlocked)
                              const Icon(
                                Icons.check_rounded,
                                size: 10,
                                color: AppTheme.green,
                              ),
                            Flexible(
                              child: Text(
                                item.isUnlocked ? 'Done' : 'Locked',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: item.isUnlocked
                                      ? AppTheme.green
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
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
                  fontSize: 12,
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
