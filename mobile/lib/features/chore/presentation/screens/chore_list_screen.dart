import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../house/domain/entities/house_models.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../domain/entities/chore_models.dart';
import '../providers/chore_providers.dart';

enum _Tab { routines, mine, team }

class ChoreListScreen extends ConsumerStatefulWidget {
  const ChoreListScreen({required this.houseId, super.key});
  final String houseId;

  @override
  ConsumerState<ChoreListScreen> createState() => _ChoreListScreenState();
}

class _ChoreListScreenState extends ConsumerState<ChoreListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _Tab.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateSchedule(String seasonId) async {
    setState(() => _generating = true);
    try {
      ref.invalidate(choreTemplatesProvider(widget.houseId));
      await ref.read(choreTemplatesProvider(widget.houseId).future);
      final dio = ref.read(dioProvider);
      await dio.post(
        '/houses/${widget.houseId}/seasons/$seasonId/generate-schedule',
      );
      if (mounted) {
        refreshHouseState(ref, houseId: widget.houseId);
        refreshChoreState(ref, widget.houseId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule generated! All members must now confirm.'),
          ),
        );
        _tabController.animateTo(_Tab.team.index);
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(context, apiErrorMessage(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSeason = ref.watch(activeSeasonProvider(widget.houseId));
    final templates = ref.watch(choreTemplatesProvider(widget.houseId));

    final seasonId = activeSeason.value?['id'] as String?;
    final seasonStatus = (activeSeason.value?['status'] as num?)?.toInt();
    final isDraft = seasonStatus == 0;
    final hasGenerated = seasonStatus != null && seasonStatus > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chores'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Routines'),
            Tab(text: 'Mine'),
            Tab(text: 'Team'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == _Tab.routines.index
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/houses/${widget.houseId}/chores/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add chore'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _RoutinesTab(
            houseId: widget.houseId,
            seasonId: seasonId,
            isDraft: isDraft,
            hasGenerated: hasGenerated,
            templates: templates,
            generating: _generating,
            onGenerate: seasonId != null
                ? () => _generateSchedule(seasonId)
                : null,
            tabController: _tabController,
          ),
          _MyChoresTab(houseId: widget.houseId, seasonId: seasonId),
          _TeamScheduleTab(houseId: widget.houseId, seasonId: seasonId),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Routines Tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RoutinesTab extends ConsumerWidget {
  const _RoutinesTab({
    required this.houseId,
    required this.seasonId,
    required this.isDraft,
    required this.hasGenerated,
    required this.templates,
    required this.generating,
    required this.onGenerate,
    required this.tabController,
  });

  final String houseId;
  final String? seasonId;
  final bool isDraft;
  final bool hasGenerated;
  final AsyncValue<List<ChoreTemplate>> templates;
  final bool generating;
  final VoidCallback? onGenerate;
  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSeason = ref.watch(activeSeasonProvider(houseId));
    final seasonId = activeSeason.value?['id'] as String?;

    return templates.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(choreTemplatesProvider(houseId)),
      ),
      data: (items) => Column(
        children: [
          // Availability Banner
          if (isDraft && seasonId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Icon(
                    Icons.calendar_today_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  title: const Text(
                    'Set your availability',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "Tell us when you're free so we can assign chores fairly",
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/houses/$houseId/seasons/$seasonId/availability',
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          // Chore list
          Expanded(
            child: items.isEmpty
                ? const EmptyView(
                    icon: Icons.playlist_add_rounded,
                    title: 'No routines yet',
                    message: 'Add the chores your household does regularly.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      hasGenerated ? 24 : 104,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _RoutineTile(chore: items[i], houseId: houseId),
                  ),
          ),
          // Generate button
          if (isDraft && items.isNotEmpty && seasonId != null)
            _GenerateButton(generating: generating, onGenerate: onGenerate),
          if (hasGenerated && items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => tabController.animateTo(_Tab.team.index),
                icon: const Icon(Icons.calendar_view_month_rounded),
                label: const Text('View Team Schedule'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({required this.chore, required this.houseId});
  final ChoreTemplate chore;
  final String houseId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: chore.type == ChoreType.bonus
            ? Theme.of(context).colorScheme.tertiaryContainer
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          chore.type == ChoreType.bonus
              ? Icons.auto_awesome_rounded
              : Icons.repeat_rounded,
          color: chore.type == ChoreType.bonus
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        chore.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${chore.frequency.label}  Â·  ${chore.karmaPoints} Karma',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 20),
        onPressed: () => context.push(
          '/houses/$houseId/chores/templates/${chore.id}/edit',
          extra: chore,
        ),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.generating, required this.onGenerate});
  final bool generating;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ready to generate the schedule?',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Make sure all members have set their availability first.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: generating ? null : onGenerate,
            icon: generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(generating ? 'Generatingâ€¦' : 'Generate Schedule'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Mine Tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MyChoresTab extends ConsumerWidget {
  const _MyChoresTab({required this.houseId, required this.seasonId});
  final String houseId;
  final String? seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (seasonId == null) {
      return const EmptyView(
        icon: Icons.event_busy_rounded,
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
              icon: Icons.task_alt_rounded,
              title: 'No chores assigned',
              message: "The schedule hasn't been generated yet, or you're all caught up!",
            );
          }
          final grouped = _groupByDate(items);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: grouped.length,
            itemBuilder: (ctx, i) {
              final entry = grouped.entries.elementAt(i);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
      final key = DateFormat('EEEE, MMM d').format(item.dueDate);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }
}

// â”€â”€â”€ Team Tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
  });
  final String houseId;
  final String seasonId;
  final List<HouseMember> members;

  @override
  ConsumerState<_TeamScheduleBody> createState() => _TeamScheduleBodyState();
}

class _TeamScheduleBodyState extends ConsumerState<_TeamScheduleBody> {
  List<dynamic> _occurrences = [];
  bool _loading = true;
  String? _filterMemberId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/houses/${widget.houseId}/seasons/${widget.seasonId}/occurrences',
      );
      if (mounted) {
        setState(() {
          _occurrences = res.data as List;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();

    final filtered = _filterMemberId == null
        ? _occurrences
        : _occurrences
              .where((o) => o['assignedUserId'] == _filterMemberId)
              .toList();

    final grouped = <String, List<dynamic>>{};
    for (final o in filtered) {
      try {
        final date = DateTime.parse(o['dueDate'] as String).toLocal();
        final key = DateFormat('EEEE, MMM d').format(date);
        grouped.putIfAbsent(key, () => []).add(o);
      } catch (_) {}
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
                          style: const TextStyle(fontSize: 10),
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
                ? const EmptyView(
                    icon: Icons.calendar_month_outlined,
                    title: 'No occurrences',
                    message: 'Generate the schedule first.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: grouped.length,
                    itemBuilder: (ctx, i) {
                      final entry = grouped.entries.elementAt(i);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              entry.key,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          ...entry.value.map(
                            (o) => _TeamOccurrenceTile(
                              occurrence: o,
                              members: widget.members,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TeamOccurrenceTile extends StatelessWidget {
  const _TeamOccurrenceTile({required this.occurrence, required this.members});
  final dynamic occurrence;
  final List<HouseMember> members;

  @override
  Widget build(BuildContext context) {
    final assignedId = occurrence['assignedUserId'] as String?;
    final assignee = assignedId != null
        ? members.firstWhere(
            (m) => m.userId == assignedId,
            orElse: () => members.first,
          )
        : null;
    final isUnassigned = assignedId == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: isUnassigned
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            isUnassigned
                ? '?'
                : (assignee!.displayName.isNotEmpty
                      ? assignee.displayName[0].toUpperCase()
                      : '?'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          occurrence['choreName'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          isUnassigned ? 'Unassigned' : assignee!.displayName,
          style: TextStyle(
            color: isUnassigned
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        trailing: Chip(
          label: Text(
            '${occurrence['snapshotKarma'] ?? occurrence['karmaPoints'] ?? 0} pts',
            style: const TextStyle(fontSize: 11),
          ),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// â”€â”€â”€ Shared â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({required this.chore, required this.houseId});
  final ChoreOccurrence chore;
  final String houseId;

  @override
  Widget build(BuildContext context) {
    final isOverdue =
        chore.status == ChoreStatus.overdue ||
        chore.status == ChoreStatus.criticalOverdue;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            isOverdue
                ? Icons.warning_amber_rounded
                : Icons.cleaning_services_outlined,
            size: 20,
            color: isOverdue
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          chore.choreName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Due ${DateFormat('HH:mm').format(chore.dueDate)}  ·  ${chore.karmaPoints} Karma',
          style: TextStyle(
            color: isOverdue ? Theme.of(context).colorScheme.error : null,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/houses/$houseId/chores/${chore.id}'),
      ),
    );
  }
}
