import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/chore_models.dart';
import '../providers/chore_providers.dart';
import '../widgets/chore_card.dart';

enum _ChoreFilter { today, upcoming, overdue }

class ChoreListScreen extends ConsumerStatefulWidget {
  const ChoreListScreen({required this.houseId, super.key});
  final String houseId;

  @override
  ConsumerState<ChoreListScreen> createState() => _ChoreListScreenState();
}

class _ChoreListScreenState extends ConsumerState<ChoreListScreen> {
  _ChoreFilter filter = _ChoreFilter.today;

  @override
  Widget build(BuildContext context) {
    final occurrences = ref.watch(myChoresProvider(widget.houseId));
    final templates = ref.watch(choreTemplatesProvider(widget.houseId));
    final karmaByChore = {
      for (final chore in templates.value ?? const <ChoreTemplate>[])
        chore.id: chore.karmaPoints,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chores'),
        actions: [
          IconButton(
            tooltip: 'Manage chore templates',
            onPressed: templates.hasValue
                ? () => _showTemplateSheet(templates.value!)
                : null,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/houses/${widget.houseId}/chores/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New chore'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SegmentedButton<_ChoreFilter>(
              segments: const [
                ButtonSegment(value: _ChoreFilter.today, label: Text('Today')),
                ButtonSegment(
                  value: _ChoreFilter.upcoming,
                  label: Text('Upcoming'),
                ),
                ButtonSegment(
                  value: _ChoreFilter.overdue,
                  label: Text('Overdue'),
                ),
              ],
              selected: {filter},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => filter = value.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                refreshChoreState(ref, widget.houseId);
                await ref.read(myChoresProvider(widget.houseId).future);
              },
              child: occurrences.when(
                loading: () => const LoadingView(),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(myChoresProvider(widget.houseId)),
                ),
                data: (items) {
                  final filtered = items.where(_matchesFilter).toList();
                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.55,
                          child: EmptyView(
                            icon: filter == _ChoreFilter.overdue
                                ? Icons.task_alt_rounded
                                : Icons.cleaning_services_rounded,
                            title: filter == _ChoreFilter.overdue
                                ? 'Nothing overdue'
                                : 'No chores here',
                            message: filter == _ChoreFilter.today
                                ? 'Your board is clear for today.'
                                : 'Pull down to check for schedule changes.',
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final chore = filtered[index];
                      return ChoreCard(
                        chore: chore,
                        karma: chore.karmaPoints > 0
                            ? chore.karmaPoints
                            : karmaByChore[chore.choreId] ?? 0,
                        onTap: () => context.push(
                          '/houses/${widget.houseId}/chores/${chore.id}',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(ChoreOccurrence chore) {
    final now = DateTime.now();
    final overdue =
        chore.status == ChoreStatus.overdue ||
        chore.status == ChoreStatus.criticalOverdue ||
        (chore.status == ChoreStatus.assigned && chore.dueDate.isBefore(now));
    return switch (filter) {
      _ChoreFilter.overdue => overdue,
      _ChoreFilter.today => !overdue && DateUtils.isSameDay(chore.dueDate, now),
      _ChoreFilter.upcoming =>
        !overdue &&
            !DateUtils.isSameDay(chore.dueDate, now) &&
            chore.dueDate.isAfter(now),
    };
  }

  Future<void> _showTemplateSheet(List<ChoreTemplate> templates) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'House routines',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Expanded(
                child: templates.isEmpty
                    ? const EmptyView(
                        icon: Icons.playlist_add_rounded,
                        title: 'No routines yet',
                        message: 'Create the first chore for this house.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: templates.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final chore = templates[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                chore.type == ChoreType.bonus
                                    ? Icons.auto_awesome_rounded
                                    : Icons.repeat_rounded,
                              ),
                            ),
                            title: Text(chore.name),
                            subtitle: Text(
                              '${chore.frequency.label} · ${chore.karmaPoints} Karma',
                            ),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              context.push(
                                '/houses/${widget.houseId}/chores/templates/${chore.id}/edit',
                                extra: chore,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
