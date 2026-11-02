import '../../../../core/utils/vietnam_time.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/network/api_client.dart';
import '../../../house/domain/entities/house_models.dart';
import '../../../../core/widgets/app_page_frame.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_states.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../domain/entities/chore_models.dart';
import '../../../house/presentation/screens/bonus_chores_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/schedule_workflow_card.dart';
import '../providers/chore_providers.dart';

enum _Tab { mine, team, bonus }

class ChoreListScreen extends ConsumerStatefulWidget {
  const ChoreListScreen({required this.houseId, this.initialTab, super.key});
  final String houseId;
  final String? initialTab;

  @override
  ConsumerState<ChoreListScreen> createState() => _ChoreListScreenState();
}

class _ChoreListScreenState extends ConsumerState<ChoreListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _initialIndex(String? tab) => switch (tab) {
    'mine' => _Tab.mine.index,
    'team' => _Tab.team.index,
    'bonus' => _Tab.bonus.index,
    _ => _Tab.mine.index,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _Tab.values.length,
      initialIndex: _initialIndex(widget.initialTab),
      vsync: this,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ChoreListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.houseId != widget.houseId) {
      _tabController.index = _initialIndex(widget.initialTab);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _tabController.index == _Tab.team.index
      ? _buildScreen(context)
      : AppPageFrame(builder: _buildScreen);

  Widget _buildScreen(BuildContext context) {
    final activeSeason = ref.watch(activeSeasonProvider(widget.houseId));
    final house = ref.watch(houseDetailProvider(widget.houseId));

    final seasonId = activeSeason.value?['id'] as String?;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerLowest,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: 'Back to Overview',
          onPressed: () => context.go('/houses/${widget.houseId}'),
          icon: const Icon(Icons.arrow_back_outlined, size: 20),
        ),
        titleSpacing: 0,
        title: const Text(
          'Chores',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Add chore',
            icon: const Icon(Icons.add),
            onPressed: () =>
                context.push('/houses/${widget.houseId}/chores/new'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Chore options',
            onSelected: (value) =>
                context.push('/houses/${widget.houseId}/$value'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'urgent-event', child: Text('Urgent event')),
              PopupMenuItem(
                value: 'unresolved-chores',
                child: Text('Needs review'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Mine'),
            Tab(text: 'Team'),
            Tab(text: 'Bonus'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: activeSeason.isLoading || house.isLoading
                ? const LoadingView()
                : activeSeason.hasError
                ? ErrorView(
                    error: activeSeason.error!,
                    onRetry: () =>
                        ref.invalidate(activeSeasonProvider(widget.houseId)),
                  )
                : house.hasError
                ? ErrorView(
                    error: house.error!,
                    onRetry: () =>
                        ref.invalidate(houseDetailProvider(widget.houseId)),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _MyChoresTab(houseId: widget.houseId, seasonId: seasonId),
                      _TeamScheduleTab(
                        houseId: widget.houseId,
                        seasonId: seasonId,
                      ),
                      seasonId == null
                          ? const Center(
                              child: Text(
                                'No season yet. Bonus chores will appear here.',
                              ),
                            )
                          : BonusChoresScreen(
                              houseId: widget.houseId,
                              seasonId: seasonId,
                              embedded: true,
                              key: ValueKey(seasonId),
                            ),
                    ],
                  ),
          ),
          if (seasonId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 8, 16, 20),
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/houses/${widget.houseId}/seasons/$seasonId/review',
                ),
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Season Schedule Review & Confirmation'),
              ),
            ),
        ],
      ),
    );
  }
}

class _MyChoresTab extends ConsumerWidget {
  const _MyChoresTab({required this.houseId, required this.seasonId});
  final String houseId;
  final String? seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (seasonId == null) {
      return const EmptyView(
        icon: Icons.event_busy_outlined,
        title: 'No active season',
        message: 'Create a season first to see your assigned chores.',
      );
    }

    final myChores = ref.watch(myChoresProvider(houseId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myChoresProvider(houseId)),
      child: myChores.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(myChoresProvider(houseId)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.task_alt_outlined,
              title: 'No chores assigned',
              message: "The schedule hasn't been generated yet, or you're all caught up!",
            );
          }
          final grouped = _groupByDate(items);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: grouped.length,
            itemBuilder: (ctx, i) {
              final entry = grouped.entries.elementAt(i);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DayHeader(label: entry.key, count: entry.value.length),
                  ...entry.value.map(
                    (chore) => _OccurrenceTile(chore: chore, houseId: houseId),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<ChoreOccurrence>> _groupByDate(List<ChoreOccurrence> items) {
    final sorted = [...items]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final grouped = <String, List<ChoreOccurrence>>{};
    for (final item in sorted) {
      final key = DateFormat('EEEE, dd/MM').format(vietnamTime(item.dueDate));
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }
}

class _TeamScheduleTab extends ConsumerWidget {
  const _TeamScheduleTab({required this.houseId, required this.seasonId});
  final String houseId;
  final String? seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (seasonId == null) {
      return const EmptyView(
        icon: Icons.group_outlined,
        title: 'No active season',
        message: 'Create and generate a season to see the full schedule.',
      );
    }

    final members = ref.watch(houseMembersProvider(houseId));

    return members.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(houseMembersProvider(houseId)),
      ),
      data: (memberList) => _TeamScheduleBody(
        key: ValueKey((houseId, seasonId)),
        houseId: houseId,
        seasonId: seasonId!,
        members: memberList.where((m) => m.isActive).toList(),
      ),
    );
  }
}

class _TeamScheduleBody extends ConsumerStatefulWidget {
  const _TeamScheduleBody({
    required this.houseId,
    required this.seasonId,
    required this.members,
    super.key,
  });
  final String houseId;
  final String seasonId;
  final List<HouseMember> members;

  @override
  ConsumerState<_TeamScheduleBody> createState() => _TeamScheduleBodyState();
}

class _TeamScheduleBodyState extends ConsumerState<_TeamScheduleBody> {
  List<ChoreOccurrence> _occurrences = [];
  Object? _error;
  bool _loading = true;
  String? _filterMemberId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/houses/${widget.houseId}/seasons/${widget.seasonId}/occurrences',
      );
      if (mounted) {
        setState(() {
          _occurrences =
              (res.data as List)
                  .map(
                    (row) => ChoreOccurrence.fromJson(
                      Map<String, dynamic>.from(row as Map),
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(choreRefreshProvider(widget.houseId), (_, _) => _fetch());
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: _fetch);

    final seasonData = ref
        .watch(activeSeasonProvider(widget.houseId))
        .asData
        ?.value;
    final status = seasonData?['status'];
    final isDraft = status == 0 || status == 'DRAFT';
    final isReviewing = status == 1 || status == 'REVIEWING';
    final isWorkflowVisible = isDraft || isReviewing || _occurrences.isEmpty;
    final myId = ref.watch(userProfileProvider).asData?.value.id;
    final isOwner = widget.members.any((m) => m.userId == myId && m.isOwner);

    final normalOccurrences = _occurrences
        .where((o) => o.type == ChoreType.normal)
        .toList();
    final mandatoryCount = normalOccurrences.length;
    final unassignedCount = normalOccurrences
        .where((o) => o.assignedUserId == null)
        .length;
    final hasOccurrences = normalOccurrences.isNotEmpty;
    final allAssigned = hasOccurrences && unassignedCount == 0;

    final filtered = _filterMemberId == null
        ? _occurrences
        : _occurrences
              .where((o) => o.assignedUserId == _filterMemberId)
              .toList();

    final grouped = <String, List<ChoreOccurrence>>{};
    for (final occurrence in filtered) {
      final key = DateFormat('EEEE, dd/MM')
          .format(vietnamTime(occurrence.dueDate));
      grouped.putIfAbsent(key, () => []).add(occurrence);
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _loading = true;
        });
        await _fetch();
      },
      child: Column(
        children: [
          // Member filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterMemberId == null,
                  onSelected: (_) => setState(() => _filterMemberId = null),
                ),
                ...widget.members.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      avatar: CircleAvatar(
                        radius: 10,
                        child: Text(
                          m.displayName.isNotEmpty
                              ? m.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      label: Text(m.displayName),
                      selected: _filterMemberId == m.userId,
                      onSelected: (_) =>
                          setState(() => _filterMemberId = m.userId),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: grouped.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      children: [
                        if (isWorkflowVisible && _filterMemberId == null)
                          ScheduleWorkflowCard(
                            houseId: widget.houseId,
                            seasonId: widget.seasonId,
                            isOwner: isOwner,
                            hasOccurrences: hasOccurrences,
                            mandatoryCount: mandatoryCount,
                            unassignedCount: unassignedCount,
                            allAssigned: allAssigned,
                            isDraft: isDraft,
                            isReviewing: isReviewing,
                            onStateChanged: _fetch,
                          ),
                        const SizedBox(height: 24),
                        const EmptyView(
                          icon: Icons.calendar_month_outlined,
                          title: 'Chưa có lịch việc',
                          message: 'Hãy nhấn nút "1. Sinh lịch việc" ở trên để chuẩn bị lịch mùa.',
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (isWorkflowVisible && _filterMemberId == null) ...[
                        ScheduleWorkflowCard(
                          houseId: widget.houseId,
                          seasonId: widget.seasonId,
                          isOwner: isOwner,
                          hasOccurrences: hasOccurrences,
                          mandatoryCount: mandatoryCount,
                          unassignedCount: unassignedCount,
                          allAssigned: allAssigned,
                          isDraft: isDraft,
                          isReviewing: isReviewing,
                          onStateChanged: _fetch,
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final entry in grouped.entries) ...[
                        _DayHeader(label: entry.key, count: entry.value.length),
                        ...entry.value.map(
                          (o) => _TeamOccurrenceTile(
                            occurrence: o,
                            houseId: widget.houseId,
                            members: widget.members,
                            onDelete: isOwner && isDraft
                                ? () => _deleteChore(o.choreId, o.choreName)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChore(String choreId, String choreName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chore?'),
        content: Text(
          'Delete "$choreName" and its draft schedule entries? Other chores in the season will stay. Chores with completed or financial history cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(dioProvider).delete('/chores/$choreId');
      refreshChoreState(ref, widget.houseId);
      await _fetch();
      if (mounted) showAppMessage(context, 'Chore deleted');
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    }
  }
}

class _TeamOccurrenceTile extends StatelessWidget {
  const _TeamOccurrenceTile({
    required this.occurrence,
    required this.members,
    required this.houseId,
    this.onDelete,
  });
  final ChoreOccurrence occurrence;
  final List<HouseMember> members;
  final String houseId;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final assignee = members
        .where((m) => m.userId == occurrence.assignedUserId)
        .firstOrNull;
    final name = occurrence.assignedUserId == null
        ? 'Unassigned'
        : assignee?.displayName ?? occurrence.assignedUserDisplayName;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colors.primaryFixed,
          foregroundColor: colors.onPrimaryFixedVariant,
          child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()),
        ),
        title: Text(
          occurrence.choreName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          name,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        trailing: onDelete == null
            ? _KarmaTag(points: occurrence.karmaPoints)
            : PopupMenuButton<String>(
                tooltip: 'Chore options',
                onSelected: (value) {
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete chore')),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _KarmaTag(points: occurrence.karmaPoints),
                ),
              ),
        onTap: () => context.push('/houses/$houseId/chores/${occurrence.id}'),
      ),
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({required this.chore, required this.houseId});
  final ChoreOccurrence chore;
  final String houseId;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overdue =
        chore.status == ChoreStatus.overdue ||
        chore.status == ChoreStatus.criticalOverdue;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: overdue
              ? colors.error.withValues(alpha: .35)
              : colors.outlineVariant.withValues(alpha: .25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: overdue ? colors.error : colors.primaryFixed,
              width: 3,
            ),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: overdue ? colors.errorContainer : colors.primaryFixed,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              overdue
                  ? Icons.warning_amber_outlined
                  : Icons.cleaning_services_outlined,
              color: overdue
                  ? colors.onErrorContainer
                  : colors.onPrimaryFixedVariant,
              size: 21,
            ),
          ),
          title: Text(
            chore.choreName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${overdue ? 'Overdue' : 'Due'} ${DateFormat('HH:mm').format(vietnamTime(chore.dueDate))}',
                  style: TextStyle(
                    fontSize: 12,
                    color: overdue ? colors.error : colors.onSurfaceVariant,
                  ),
                ),
                _KarmaTag(points: chore.karmaPoints),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right_outlined, size: 18),
          onTap: () => context.push('/houses/$houseId/chores/${chore.id}'),
        ),
      ),
    );
  }
}

class _KarmaTag extends StatelessWidget {
  const _KarmaTag({required this.points});
  final int points;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.tertiaryFixed,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$points Karma',
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
            '$count chores',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
