import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/gamification_models.dart';
import '../providers/gamification_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({
    required this.houseId,
    required this.seasonId,
    super.key,
  });
  final String houseId, seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (houseId: houseId, seasonId: seasonId);
    final rankings = ref.watch(leaderboardProvider(key));
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(leaderboardProvider(key));
          await ref.read(leaderboardProvider(key).future);
        },
        child: rankings.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(leaderboardProvider(key)),
          ),
          data: (items) {
            final sorted = [...items]..sort((a, b) => a.rank.compareTo(b.rank));
            final podium = sorted.take(3).toList();
            if (podium.length > 1) {
              final first = podium[0];
              podium[0] = podium[1];
              podium[1] = first;
            }
            final completed = sorted.fold<int>(
              0,
              (total, member) => total + member.choresCompleted,
            );
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  'Season standings',
                  style: TextStyle(color: colors.primary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  'House standings',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No rankings yet. Complete chores to put points on the board.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (podium.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final member in podium)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _PodiumPlace(member: member),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 20),
                if (sorted.isNotEmpty)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Chore contribution',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push(
                                  '/houses/$houseId/karma/history',
                                ),
                                child: const Text(
                                  'View History',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          for (final member in sorted)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colors.primaryFixed,
                                    foregroundColor: colors.primary,
                                    child: Text(
                                      member.displayName.isEmpty
                                          ? '?'
                                          : member.displayName.characters.first
                                                .toUpperCase(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Rank #${member.rank}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${member.choresCompleted} completed',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: completed == 0
                                              ? 0
                                              : member.choresCompleted /
                                                    completed,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          minHeight: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            'Share of completed chores this season',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onSurfaceVariant,
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

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({required this.member});
  final SeasonRanking member;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final winner = member.rank == 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (winner)
          Icon(
            Icons.workspace_premium_rounded,
            color: colors.tertiary,
            size: 24,
          ),
        CircleAvatar(
          radius: winner ? 27 : 23,
          backgroundColor: winner
              ? colors.primaryFixed
              : colors.surfaceContainerHighest,
          foregroundColor: colors.primary,
          child: Text(
            member.displayName.isEmpty
                ? '?'
                : member.displayName.characters.first.toUpperCase(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          member.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: winner ? 22 : 16,
            horizontal: 4,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: winner
                  ? colors.tertiaryFixedDim
                  : colors.outlineVariant.withValues(alpha: .4),
            ),
          ),
          child: Column(
            children: [
              Text(
                '#${member.rank}',
                style: TextStyle(
                  fontSize: winner ? 28 : 23,
                  fontWeight: FontWeight.w800,
                  color: winner ? colors.tertiary : colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${member.totalKarma > 0 ? '+' : ''}${member.totalKarma} Karma',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: member.totalKarma < 0 ? colors.error : colors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${member.choresCompleted} tasks done',
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
