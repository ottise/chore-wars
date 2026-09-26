import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/gamification_models.dart';
import '../providers/gamification_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({
    required this.houseId,
    required this.seasonId,
    super.key,
  });
  final String houseId;
  final String seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (houseId: houseId, seasonId: seasonId);
    final rankings = ref.watch(leaderboardProvider(key));
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
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
            if (items.isEmpty) {
              return const EmptyView(
                icon: Icons.emoji_events_outlined,
                title: 'No rankings yet',
                message: 'Complete chores to put points on the board.',
              );
            }
            final sorted = [...items]..sort((a, b) => a.rank.compareTo(b.rank));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Current season',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'House standings',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                _Podium(rankings: sorted.take(3).toList()),
                const SizedBox(height: 24),
                for (final member in sorted.skip(3)) ...[
                  _RankingRow(member: member),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.rankings});
  final List<SeasonRanking> rankings;

  @override
  Widget build(BuildContext context) {
    final byRank = {for (final item in rankings) item.rank: item};
    return SizedBox(
      height: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumPlace(member: byRank[2], rank: 2, height: 142),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PodiumPlace(member: byRank[1], rank: 1, height: 190),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PodiumPlace(member: byRank[3], rank: 3, height: 118),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.member,
    required this.rank,
    required this.height,
  });
  final SeasonRanking? member;
  final int rank;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (member == null) return const SizedBox.shrink();
    final color = switch (rank) {
      1 => AppTheme.yellow,
      2 => const Color(0xFFCFD4DA),
      _ => const Color(0xFFC98755),
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: rank == 1 ? 30 : 25,
          backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
          child: Text(
            member!.displayName.characters.first.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.purple,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          member!.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${member!.totalKarma} Karma',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.member});
  final SeasonRanking member;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: SizedBox(
        width: 36,
        child: Center(
          child: Text(
            '#${member.rank}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
        ),
      ),
      title: Text(member.displayName),
      subtitle: Text('${member.choresCompleted} chores completed'),
      trailing: Text(
        '${member.totalKarma}',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: AppTheme.purple),
      ),
    ),
  );
}
