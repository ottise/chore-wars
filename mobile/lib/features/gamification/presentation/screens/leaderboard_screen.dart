import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_page_frame.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/member_avatar.dart';
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
      backgroundColor: colors.surface,
      appBar: AppBar(
        toolbarHeight: 68,
        leadingWidth: 64,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 0, 12),
          child: BackButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E293B),
              side: const BorderSide(color: Color(0xFFE8ECF2)),
              iconSize: 19,
              shape: const CircleBorder(),
            ),
          ),
        ),
        titleSpacing: 12,
        title: const Text(
          'Leaderboard',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: [
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
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: _PodiumPlace(
                              houseId: houseId,
                              member: member,
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 22),
                if (sorted.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C1E293B),
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Chore contribution',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push(
                                '/houses/$houseId/karma/history',
                              ),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                foregroundColor: const Color(0xFF7C4DFF),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View History',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF7C4DFF),
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: Color(0xFF7C4DFF),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (var i = 0; i < sorted.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 22,
                              thickness: 1,
                              color: Color(0xFFF1F5F9),
                            ),
                          _ContributionRow(
                            houseId: houseId,
                            member: sorted[i],
                            totalCompleted: completed,
                          ),
                        ],
                      ],
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

class _PodiumPlace extends ConsumerWidget {
  const _PodiumPlace({required this.houseId, required this.member});
  final String houseId;
  final SeasonRanking member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref
        .watch(
          memberAvatarProvider((
            house: houseId,
            user: member.userId,
            version: '',
          )),
        )
        .asData
        ?.value;

    final rank = member.rank;
    final winner = rank == 1;
    final isThird = rank == 3;

    final ringColor = winner
        ? const Color(0xFF7C4DFF)
        : isThird
        ? const Color(0xFFF5B041)
        : const Color(0xFFCBD5E1);
    final avatarFill = winner
        ? const Color(0xFFEDE7FF)
        : isThird
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFE2E8F0);
    final initialColor = winner
        ? const Color(0xFF6845D6)
        : isThird
        ? const Color(0xFF92400E)
        : const Color(0xFF334155);
    final badgeColor = winner
        ? const Color(0xFF7C4DFF)
        : isThird
        ? const Color(0xFFC26A1B)
        : const Color(0xFF475569);
    final rankTextColor = winner
        ? const Color(0xFF7C4DFF)
        : isThird
        ? const Color(0xFF9A4A06)
        : const Color(0xFF475569);
    final cardBorderColor = winner
        ? const Color(0xFFC4B5FD)
        : isThird
        ? const Color(0xFFFCE3B4)
        : const Color(0xFFE8ECF2);

    final positive = member.totalKarma >= 0;
    final karmaTextColor = positive
        ? const Color(0xFF0D9488)
        : const Color(0xFFBA1A1A);
    final karmaBgColor = positive
        ? const Color(0xFFE6F7F2)
        : const Color(0xFFFFDAD6);
    final karmaBorderColor = positive
        ? const Color(0xFFB2EBE0)
        : const Color(0xFFFFB4AB);

    final avatarSize = winner ? 74.0 : 60.0;
    final tasksLabel = member.choresCompleted == 1
        ? '1 task done'
        : '${member.choresCompleted} tasks done';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: winner ? 96 : 74,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (winner)
                const Positioned(
                  top: 0,
                  left: 10,
                  child: CustomPaint(
                    size: Size(20, 15),
                    painter: _CrownPainter(color: Color(0xFF7C4DFF)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  padding: EdgeInsets.all(winner ? 3.0 : 2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: ringColor,
                      width: winner ? 2.0 : 1.5,
                    ),
                    boxShadow: winner
                        ? const [
                            BoxShadow(
                              color: Color(0x227C4DFF),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: avatarFill,
                      image: bytes != null
                          ? DecorationImage(
                              image: MemoryImage(bytes),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: bytes == null
                        ? Text(
                            member.displayName.isEmpty
                                ? '?'
                                : member.displayName.characters.first
                                      .toUpperCase(),
                            style: TextStyle(
                              fontSize: winner ? 22 : 18,
                              fontWeight: FontWeight.w700,
                              color: initialColor,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.1,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: winner ? FontWeight.w700 : FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 6,
            vertical: winner ? 14 : 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: winner
                  ? const [Color(0xFFF3EEFF), Colors.white]
                  : isThird
                  ? const [Color(0xFFFFFCF5), Colors.white]
                  : const [Colors.white, Colors.white],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cardBorderColor,
              width: winner ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: winner
                    ? const Color(0x1F6845D6)
                    : const Color(0x081E293B),
                blurRadius: winner ? 16 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  fontSize: winner ? 24 : 21,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: rankTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: karmaBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: karmaBorderColor, width: 0.8),
                ),
                child: Text(
                  '${member.totalKarma > 0 ? '+' : ''}${member.totalKarma} Karma',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: karmaTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tasksLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: winner ? FontWeight.w700 : FontWeight.w500,
                  color: winner
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContributionRow extends ConsumerWidget {
  const _ContributionRow({
    required this.houseId,
    required this.member,
    required this.totalCompleted,
  });

  final String houseId;
  final SeasonRanking member;
  final int totalCompleted;

  String _shortAvatarLabel(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length == 1) {
      return words.first.characters.take(3).toString();
    }
    return words
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Uint8List? bytes = ref
        .watch(
          memberAvatarProvider((
            house: houseId,
            user: member.userId,
            version: '',
          )),
        )
        .asData
        ?.value;

    final isFirst = member.rank == 1;
    final hasCompleted = member.choresCompleted > 0;
    final ratio = totalCompleted == 0
        ? 0.0
        : (member.choresCompleted / totalCompleted).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFirst
                  ? const Color(0xFFEDE7FF)
                  : const Color(0xFFF1F5F9),
              image: bytes != null
                  ? DecorationImage(
                      image: MemoryImage(bytes),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: bytes == null
                ? Text(
                    _shortAvatarLabel(member.displayName),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isFirst
                          ? const Color(0xFF6845D6)
                          : const Color(0xFF334155),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rank #${member.rank}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${member.choresCompleted} completed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: hasCompleted
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: hasCompleted
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF7C4DFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.08, size.height * 0.25)
      ..lineTo(size.width * 0.34, size.height * 0.58)
      ..lineTo(size.width * 0.50, 0)
      ..lineTo(size.width * 0.66, size.height * 0.58)
      ..lineTo(size.width * 0.92, size.height * 0.25)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) =>
      oldDelegate.color != color;
}
