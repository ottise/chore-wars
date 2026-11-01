import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../bounty/presentation/providers/bounty_providers.dart';
import '../../../chat/presentation/widgets/assistant_requests.dart';
import '../../../chat/providers/action_proposal_providers.dart';
import '../../../chore/presentation/providers/chore_providers.dart';
import '../../../chore/domain/entities/chore_models.dart';
import '../../../chat/data/models/action_proposal_model.dart';

class BonusChoresScreen extends ConsumerStatefulWidget {
  const BonusChoresScreen({
    required this.houseId,
    required this.seasonId,
    this.embedded = false,
    super.key,
  });
  final String houseId;
  final String seasonId;
  final bool embedded;
  @override
  ConsumerState<BonusChoresScreen> createState() => _BonusChoresScreenState();
}

class _BonusChoresScreenState extends ConsumerState<BonusChoresScreen> {
  List<Map<String, dynamic>> _chores = [];
  bool _loading = true;
  bool _fetching = false;
  bool _reload = false;
  final _claiming = <String>{};
  Object? _error;

  String? get _userId {
    final auth = ref.read(authStateProvider);
    return ref.read(userProfileProvider).asData?.value.id ??
        (auth is AuthAuthenticated ? auth.user.userId : null);
  }

  @override
  void initState() {
    super.initState();
    _fetchBonusChores();
  }

  @override
  void didUpdateWidget(covariant BonusChoresScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId ||
        oldWidget.seasonId != widget.seasonId) {
      _chores = [];
      _loading = true;
      _fetchBonusChores();
    }
  }

  Future<void> _fetchBonusChores() async {
    if (_fetching) {
      _reload = true;
      return;
    }
    _fetching = true;
    final houseId = widget.houseId;
    final seasonId = widget.seasonId;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/houses/$houseId/seasons/$seasonId/occurrences',
      );
      final bounties = await dio.get('/houses/$houseId/bounties');
      final me = _userId;
      final accepted = {
        for (final b in bounties.data as List)
          if (me != null &&
              (b['status'] == 1 || b['status'] == 'CLAIMED') &&
              _sameId(b['assignedUserId'], me))
            b['choreOccurrenceId'].toString(): b,
      };
      final now = DateTime.now();
      final chores = (res.data as List)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .where((c) {
            if (accepted.containsKey(c['id'].toString())) return true;
            if (c['type'] != 1 && c['type'] != 'BONUS') return false;
            final assignedTo = c['assignedUserId']?.toString();
            final mine = me != null && _sameId(assignedTo, me);
            final pending =
                c['status'] == 0 || c['status'] == 'ASSIGNED';
            final due = DateTime.tryParse(c['dueDate'].toString());
            if (mine) return true;

            // Urgent AI campaign chores are assigned to individual members,
            // but every participant needs to see the shared preparation plan.
            // Keep completed/expired chores out of other members' view.
            return pending && (due?.isAfter(now) ?? false);
          })
          .map(
            (c) => {
              ...c,
              if (accepted.containsKey(c['id'].toString()))
                'bounty': accepted[c['id'].toString()],
            },
          )
          .toList();
      chores.sort((a, b) {
        final due = a['dueDate'].toString().compareTo(b['dueDate'].toString());
        return due != 0
            ? due
            : a['id'].toString().compareTo(b['id'].toString());
      });
      if (mounted && houseId == widget.houseId && seasonId == widget.seasonId) {
        setState(() {
          _chores = chores;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && houseId == widget.houseId && seasonId == widget.seasonId) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    } finally {
      _fetching = false;
      if (mounted && _reload) {
        _reload = false;
        _fetchBonusChores();
      }
    }
  }

  bool _sameId(Object? left, Object? right) =>
      left?.toString().toLowerCase() == right?.toString().toLowerCase();

  Future<void> _refresh() async {
    final room = ref
        .read(assistantRequestRoomProvider(widget.houseId))
        .asData
        ?.value;
    if (room == null) {
      ref.invalidate(assistantRequestRoomProvider(widget.houseId));
    } else {
      await ref.read(actionProposalProvider(room).notifier).loadProposals();
    }
    await _fetchBonusChores();
  }

  Future<void> _claimChore(String id) async {
    if (!_claiming.add(id)) return;
    setState(() {});
    try {
      await ref.read(dioProvider).post('/occurrences/$id/claim');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bonus chore claimed successfully!')),
        );
        refreshChoreState(ref, widget.houseId);
        await _fetchBonusChores();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _claiming.remove(id));
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(
    List<Map<String, dynamic>> items,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final dueStr = item['dueDate']?.toString();
      final dt = dueStr != null ? DateTime.tryParse(dueStr) : null;
      final key = dt != null
          ? DateFormat('EEEE, dd/MM').format(vietnamTime(dt))
          : 'Upcoming';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  Widget _chore(Map<String, dynamic> c) {
    final colors = Theme.of(context).colorScheme;
    final id = c['id'].toString();
    final assignedTo = c['assignedUserId']?.toString();
    final assignedToMe = _userId != null && _sameId(assignedTo, _userId);
    final unassigned = assignedTo == null;
    final owned = assignedToMe || c['bounty'] != null;
    final displayName = c['assignedUserDisplayName']?.toString().trim() ?? '';
    final assigneeName = unassigned
        ? 'Unassigned'
        : assignedToMe
            ? 'Assigned to you'
            : displayName.isNotEmpty
                ? 'Assigned to $displayName'
                : 'Assigned';
    final initial = unassigned
        ? 'U'
        : assignedToMe
            ? 'Y'
            : displayName.isNotEmpty
                ? displayName[0].toUpperCase()
                : '?';
    final dueDate = DateTime.tryParse(c['dueDate']?.toString() ?? '');
    final plannedStart =
        DateTime.tryParse(c['plannedStartAt']?.toString() ?? '');
    final statusObj = ChoreStatus.fromJson(c['status']);
    final isOverdue =
        statusObj == ChoreStatus.overdue ||
        statusObj == ChoreStatus.criticalOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue
              ? colors.error.withValues(alpha: .35)
              : colors.outlineVariant.withValues(alpha: .25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/houses/${widget.houseId}/chores/$id'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isOverdue
                    ? colors.error
                    : assignedToMe
                        ? colors.primaryFixed
                        : const Color(0xFFF59E0B),
                width: 3,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: assignedToMe
                          ? colors.primaryFixed
                          : unassigned
                              ? const Color(0xFFEDE9FE)
                              : colors.surfaceContainerHighest,
                      foregroundColor: assignedToMe
                          ? colors.onPrimaryFixedVariant
                          : unassigned
                              ? const Color(0xFF7C3AED)
                              : colors.onSurfaceVariant,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['choreName']?.toString() ?? 'Bonus chore',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            assigneeName,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _BonusRewardTag(
                      karma: c['karmaPoints'] as int? ?? 0,
                      bountyAmount: c['bounty'] != null
                          ? c['bounty']['amount'] as num?
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (dueDate != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: isOverdue
                                ? colors.error
                                : colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${isOverdue ? 'Overdue' : 'Due'} ${DateFormat('HH:mm').format(vietnamTime(dueDate))}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isOverdue
                                  ? colors.error
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    if (plannedStart != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_circle_outline_rounded,
                            size: 12,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Prep ${DateFormat('HH:mm').format(vietnamTime(plannedStart))}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    if (owned && statusObj != ChoreStatus.assigned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusObj.label,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isOverdue
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (unassigned && !owned) ...[
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _claiming.contains(id)
                            ? null
                            : () => _claimChore(id),
                        child: Text(
                          _claiming.contains(id) ? 'Claiming…' : 'Claim',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        foregroundColor: colors.primary,
                      ),
                      onPressed: () => context.push(
                        '/houses/${widget.houseId}/chores/$id',
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View chore',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bountyBoardProvider(widget.houseId), (_, next) {
      if (next.hasValue) _fetchBonusChores();
    });
    ref.listen(
      choreRefreshProvider(widget.houseId),
      (_, _) => _fetchBonusChores(),
    );
    ref.listen(userProfileProvider, (_, next) {
      if (next.hasValue) _fetchBonusChores();
    });
    final roomId = ref
        .watch(assistantRequestRoomProvider(widget.houseId))
        .asData
        ?.value;
    if (roomId != null) {
      ref.listen(actionProposalProvider(roomId), (previous, next) {
        final old = previous?.asData?.value ?? <ActionProposalModel>[];
        final approved =
            next.asData?.value.any(
              (proposal) =>
                  proposal.type == ProposalType.urgentEvent &&
                  proposal.status == ProposalStatus.approved &&
                  !old.any(
                    (p) =>
                        p.id == proposal.id &&
                        p.status == ProposalStatus.approved,
                  ),
            ) ??
            false;
        if (approved) _fetchBonusChores();
      });
    }
    final grouped = _groupByDate(_chores);
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          AssistantRequests(
            houseId: widget.houseId,
            urgentOnly: true,
            inline: true,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(apiErrorMessage(_error!)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _fetchBonusChores,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry bonus chores'),
                  ),
                ],
              ),
            )
          else if (_chores.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: EmptyView(
                icon: Icons.stars_rounded,
                title: 'No bonus chores yet',
                message: 'Pending invitations or urgent tasks will appear here.',
              ),
            )
          else ...[
            for (final entry in grouped.entries) ...[
              _DayHeader(label: entry.key, count: entry.value.length),
              ...entry.value.map(_chore),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Bonus Chores')),
            body: body,
          );
  }
}

class _BonusRewardTag extends StatelessWidget {
  const _BonusRewardTag({this.karma, this.bountyAmount});
  final int? karma;
  final num? bountyAmount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (bountyAmount != null && bountyAmount! > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$bountyAmount VND',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFFB45309),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.tertiaryFixed,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${karma ?? 0} Karma',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.onTertiaryFixedVariant,
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 13, color: colors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count ${count == 1 ? 'chore' : 'chores'}',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
