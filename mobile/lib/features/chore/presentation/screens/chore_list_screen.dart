import '../../../chat/providers/action_proposal_providers.dart';
import '../../../chat/presentation/widgets/urgent_event_banner.dart';

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
import '../../domain/entities/routine_preset.dart';
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
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
    final urgent = ref
        .watch(activeUrgentEventForHouseProvider(widget.houseId))
        .asData
        ?.value;
    final templates = ref.watch(choreTemplatesProvider(widget.houseId));
    final house = ref.watch(houseDetailProvider(widget.houseId));

    final seasonId = activeSeason.value?['id'] as String?;
    final seasonStatus = (activeSeason.value?['status'] as num?)?.toInt();
    final isDraft = seasonStatus == 0;
    final hasGenerated = seasonStatus != null && seasonStatus > 0;
    final isOwner = house.value?.myRole == HouseRole.owner;

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
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        titleSpacing: 0,
        title: const Text(
          'Chores',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (seasonStatus == 2)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                shape: const StadiumBorder(),
              ),
              onPressed: () =>
                  context.push('/houses/${widget.houseId}/urgent-event'),
              child: const Text('Urgent'),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Theme.of(context).colorScheme.tertiaryFixed,
                foregroundColor: Theme.of(context)
                    .colorScheme
                    .onTertiaryFixedVariant,
                shape: const StadiumBorder(),
              ),
              onPressed: () =>
                  context.push('/houses/${widget.houseId}/unresolved-chores'),
              child: const Text('Needs Review'),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Routines'),
            Tab(text: 'Mine'),
            Tab(text: 'Team'),
          ],
        ),
      ),
      floatingActionButton:
          _tabController.index == _Tab.routines.index &&
              isOwner &&
              (templates.asData?.value.isNotEmpty == true)
          ? FloatingActionButton.extended(
              onPressed: () => context.push(
                '/houses/${widget.houseId}/chores/new?routine=true',
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Routine'),
            )
          : null,
      body: Column(
        children: [
          if (urgent != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 112),
              child: SingleChildScrollView(
                child: UrgentEventBanner(proposal: urgent),
              ),
            ),
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
                      _RoutinesTab(
                        houseId: widget.houseId,
                        seasonId: seasonId,
                        isDraft: isDraft,
                        canCreate: isOwner,
                        hasGenerated: hasGenerated,
                        templates: templates,
                        generating: _generating,
                        onGenerate: seasonId != null && isOwner
                            ? () => _generateSchedule(seasonId)
                            : null,
                        tabController: _tabController,
                      ),
                      _MyChoresTab(houseId: widget.houseId, seasonId: seasonId),
                      _TeamScheduleTab(
                        houseId: widget.houseId,
                        seasonId: seasonId,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoutinesTab extends ConsumerWidget {
  const _RoutinesTab({
    required this.houseId,
    required this.seasonId,
    required this.isDraft,
    required this.canCreate,
    required this.hasGenerated,
    required this.templates,
    required this.generating,
    required this.onGenerate,
    required this.tabController,
  });

  final String houseId;
  final String? seasonId;
  final bool isDraft;
  final bool canCreate;
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
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(choreTemplatesProvider(houseId)),
              child: items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _RoutineEmpty(
                          onCreate: canCreate
                              ? () => context.push(
                                  '/houses/$houseId/chores/new?routine=true',
                                )
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Popular Templates',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 10),
                        for (final preset in RoutinePreset.values)
                          _RoutinePresetTile(
                            preset: preset,
                            onAdd: canCreate
                                ? () => context.push(
                                    '/houses/$houseId/chores/new?routine=true&preset=${preset.key}',
                                  )
                                : null,
                          ),
                      ],
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
      tileColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: .25),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        foregroundColor: Theme.of(context).colorScheme.onPrimaryFixedVariant,
        backgroundColor: chore.type == ChoreType.bonus
            ? Theme.of(context).colorScheme.tertiaryFixed
            : Theme.of(context).colorScheme.primaryFixed,
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
        '${chore.frequency.label}  ·  ${chore.karmaPoints} Karma',
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
            label: Text(generating ? 'Generating…' : 'Generate Schedule'),
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
      final key = DateFormat('EEEE, dd/MM').format(item.dueDate);
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
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: _fetch);

    final filtered = _filterMemberId == null
        ? _occurrences
        : _occurrences
              .where((o) => o.assignedUserId == _filterMemberId)
              .toList();

    final grouped = <String, List<ChoreOccurrence>>{};
    for (final occurrence in filtered) {
      final key = DateFormat('EEEE, dd/MM').format(occurrence.dueDate);
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
                          _DayHeader(
                            label: entry.key,
                            count: entry.value.length,
                          ),
                          ...entry.value.map(
                            (o) => _TeamOccurrenceTile(
                              occurrence: o,
                              houseId: widget.houseId,
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
  const _TeamOccurrenceTile({
    required this.occurrence,
    required this.members,
    required this.houseId,
  });
  final ChoreOccurrence occurrence;
  final List<HouseMember> members;
  final String houseId;
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
        borderRadius: BorderRadius.circular(20),
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
        trailing: _KarmaTag(points: occurrence.karmaPoints),
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
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: overdue
              ? colors.error.withValues(alpha: .35)
              : colors.outlineVariant.withValues(alpha: .25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
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
                ? Icons.warning_amber_rounded
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
                '${overdue ? 'Overdue' : 'Due'} ${DateFormat('HH:mm').format(chore.dueDate)}',
                style: TextStyle(
                  fontSize: 11,
                  color: overdue ? colors.error : colors.onSurfaceVariant,
                ),
              ),
              _KarmaTag(points: chore.karmaPoints),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
        onTap: () => context.push('/houses/$houseId/chores/${chore.id}'),
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
          fontSize: 10,
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
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count chores',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _RoutineEmpty extends StatelessWidget {
  const _RoutineEmpty({this.onCreate});
  final VoidCallback? onCreate;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.surfaceContainerLowest,
              Color.alphaBlend(
                colors.primaryFixed.withValues(alpha: .2),
                colors.surfaceContainerLowest,
              ),
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryFixed,
              ),
              child: Icon(
                Icons.update_rounded,
                size: 28,
                color: colors.onPrimaryFixedVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Routines Configured Yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              onCreate != null
                  ? 'Create recurring routines, then import them into a draft season to plan your chores.'
                  : 'The owner can create recurring routines for your household.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.5,
                fontSize: 12,
              ),
            ),
            if (onCreate != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create First Routine'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoutinePresetTile extends StatelessWidget {
  const _RoutinePresetTile({required this.preset, this.onAdd});
  final RoutinePreset preset;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primaryFixed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                switch (preset) {
                  RoutinePreset.deepClean => Icons.auto_awesome_rounded,
                  RoutinePreset.dishes => Icons.flatware_rounded,
                  RoutinePreset.recycling => Icons.recycling_rounded,
                },
                size: 20,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${preset.schedule} · +${preset.karma} Karma',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onAdd != null)
              TextButton(onPressed: onAdd, child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}
