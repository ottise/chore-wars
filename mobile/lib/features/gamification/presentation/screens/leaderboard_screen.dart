import '../../../../core/widgets/member_avatar.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_page_frame.dart';

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
  Widget build(BuildContext context, WidgetRef ref) =>
      AppPageFrame(builder: (context) => _buildScreen(context, ref));

  Widget _buildScreen(BuildContext context, WidgetRef ref) {
    final key = (houseId: houseId, seasonId: seasonId);
    final rankings = ref.watch(leaderboardProvider(key));
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppPageBar(title: 'Leaderboard'),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
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
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push(
                                  '/houses/$houseId/karma/history',
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(44, 32),
                                ),
                                child: const Text(
                                  'View History',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          for (final member in sorted)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  MemberAvatar(
                                    houseId: houseId,
                                    userId: member.userId,
                                    name: member.displayName,
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
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 90,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${member.choresCompleted} completed',
                                          style: const TextStyle(
                                            fontSize: 12,
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
                                          color: member.rank == 1
                                              ? AppPageFrame.accent
                                              : colors.tertiaryFixedDim,
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
                              fontSize: 12,
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
    final positive = member.totalKarma >= 0;
    final scoreColor = positive ? const Color(0xFF008568) : colors.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: winner ? 90 : 76,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (winner)
                Positioned(
                  top: 0,
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    size: 22,
                    color: colors.tertiary,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Container(
                  width: winner ? 64 : 56,
                  height: winner ? 64 : 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: winner
                        ? colors.primaryFixed
                        : colors.surfaceContainerHighest,
                    border: Border.all(
                      color: winner
                          ? AppPageFrame.accent
                          : colors.surfaceContainerLowest,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    member.displayName.isEmpty
                        ? '?'
                        : member.displayName.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: winner ? colors.primary : colors.onSurface,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: winner ? colors.tertiary : colors.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.surfaceContainerLowest,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '#${member.rank}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          member.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: winner ? 14 : 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                winner
                    ? colors.tertiaryFixed.withValues(alpha: .25)
                    : colors.surfaceContainerLow,
                colors.surfaceContainerLowest,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: winner ? colors.tertiaryFixedDim : colors.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              Text(
                '#${member.rank}',
                style: TextStyle(
                  fontSize: winner ? 28 : 24,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: winner ? colors.tertiary : colors.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${member.totalKarma > 0 ? '+' : ''}${member.totalKarma} Karma',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scoreColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${member.choresCompleted} tasks done',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
