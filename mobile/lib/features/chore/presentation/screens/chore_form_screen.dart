import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/chore_models.dart';
import '../../domain/entities/routine_preset.dart';
import '../providers/chore_providers.dart';

class ChoreFormScreen extends ConsumerStatefulWidget {
  const ChoreFormScreen({
    required this.houseId,
    this.initial,
    this.createRoutine = false,
    this.preset,
    super.key,
  });
  final String houseId;
  final ChoreTemplate? initial;
  final bool createRoutine;
  final RoutinePreset? preset;

  @override
  ConsumerState<ChoreFormScreen> createState() => _ChoreFormScreenState();
}

class ChoreEditLoaderScreen extends ConsumerWidget {
  const ChoreEditLoaderScreen({
    required this.houseId,
    required this.choreId,
    this.initial,
    super.key,
  });

  final String houseId;
  final String choreId;
  final ChoreTemplate? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initial != null) {
      return ChoreFormScreen(houseId: houseId, initial: initial);
    }
    final templates = ref.watch(choreTemplatesProvider(houseId));
    return templates.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit chore')),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(choreTemplatesProvider(houseId)),
        ),
      ),
      data: (items) {
        ChoreTemplate? match;
        for (final item in items) {
          if (item.id == choreId) match = item;
        }
        if (match == null) {
          return const Scaffold(
            body: EmptyView(
              icon: Icons.search_off_outlined,
              title: 'Chore not found',
              message: 'It may have been deleted by another house member.',
            ),
          );
        }
        return ChoreFormScreen(houseId: houseId, initial: match);
      },
    );
  }
}

class _ChoreFormScreenState extends ConsumerState<ChoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _karma;
  late final TextEditingController _frequencyValue;
  late ChoreType _type;
  late ChoreFrequency _frequency;
  late Set<int> _days;
  late ChoreEffort _difficulty;
  late final TextEditingController _estimatedMinutes;
  final _requestId = const Uuid().v4();
  bool _asRoutine = false;
  int _deadlineMinutes = 1439;
  DateTime? _anchor;
  final List<String> _customDates = [];
  bool _saving = false;
  String? _apiError;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final chore = widget.initial;
    final preset = widget.preset;
    _asRoutine = false;
    _deadlineMinutes =
        chore?.deadlineMinutes ?? preset?.deadlineMinutes ?? 1439;
    _anchor = DateTime.tryParse(chore?.recurrenceAnchor ?? '');
    _customDates.addAll(chore?.customDates ?? const []);
    _name = TextEditingController(text: chore?.name ?? preset?.title ?? '');
    _description = TextEditingController(text: chore?.description ?? '');
    _karma = TextEditingController(
      text: (chore?.karmaPoints ?? preset?.karma)?.toString() ?? '',
    );
    _frequencyValue = TextEditingController(
      text: chore?.frequencyValue?.toString() ?? '',
    );
    _type = chore?.type ?? ChoreType.normal;
    _frequency = chore?.frequency ?? preset?.frequency ?? ChoreFrequency.daily;
    _days = {...?(chore?.frequencyDays ?? preset?.days)};
    _difficulty = chore?.difficulty ?? ChoreEffort.medium;
    _estimatedMinutes = TextEditingController(
      text: (chore?.estimatedMinutes ?? preset?.minutes ?? 30).toString(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _karma.dispose();
    _frequencyValue.dispose();
    _estimatedMinutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _editing
            ? 'Edit chore'
            : _asRoutine
            ? 'Create chore'
            : 'Create chore',
      ),
      actions: _editing
          ? [
              IconButton(
                tooltip: 'Delete chore',
                onPressed: _saving ? null : _confirmDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.red,
              ),
              const SizedBox(width: 4),
            ]
          : null,
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Take out the trash',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a chore name'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            minLines: 3,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Add a clear finish line for this task',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          Text('Chore type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ChoreType>(
            segments: const [
              ButtonSegment(
                value: ChoreType.normal,
                icon: Icon(Icons.repeat_outlined),
                label: Text('Normal'),
              ),
              ButtonSegment(
                value: ChoreType.bonus,
                icon: Icon(Icons.auto_awesome_outlined),
                label: Text('Bonus'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _karma,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Karma',
              suffixText: 'points',
            ),
            validator: (value) {
              final parsed = int.tryParse(value ?? '');
              return parsed == null || parsed <= 0
                  ? 'Karma must be greater than 0'
                  : null;
            },
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ChoreEffort>(
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: [
                    for (final effort in ChoreEffort.values)
                      DropdownMenuItem(
                        value: effort,
                        child: Text(effort.label),
                      ),
                  ],
                  onChanged: (value) => setState(() => _difficulty = value!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Default effort: ${_difficulty == ChoreEffort.easy
                      ? 15
                      : _difficulty == ChoreEffort.hard
                      ? 45
                      : 30} min',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<ChoreFrequency>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: [
              for (final frequency in ChoreFrequency.values)
                DropdownMenuItem(
                  value: frequency,
                  child: Text(frequency.label),
                ),
            ],
            onChanged: (value) => setState(() => _frequency = value!),
          ),
          if (_frequency.needsValue) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _frequencyValue,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _frequency == ChoreFrequency.xTimesPerWeek
                    ? 'Times per week'
                    : 'Interval',
              ),
              validator: (value) {
                if (!_frequency.needsValue) return null;
                final parsed = int.tryParse(value ?? '');
                return parsed == null || parsed <= 0
                    ? 'Enter a value greater than 0'
                    : null;
              },
            ),
          ],
          if ([
            ChoreFrequency.specificDays,
            ChoreFrequency.xTimesPerWeek,
            ChoreFrequency.weekly,
          ].contains(_frequency)) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var day = 0; day < 7; day++)
                  FilterChip(
                    label: Text(
                      const [
                        'Sun',
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                      ][day],
                    ),
                    selected: _days.contains(day),
                    onSelected: (selected) => setState(() {
                      selected ? _days.add(day) : _days.remove(day);
                    }),
                  ),
              ],
            ),
            if (_days.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Choose at least one day.',
                  style: TextStyle(color: AppTheme.red, fontSize: 12),
                ),
              ),
          ],
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Deadline (Vietnam time)'),
            subtitle: Text(
              '${(_deadlineMinutes ~/ 60).toString().padLeft(2, '0')}:${(_deadlineMinutes % 60).toString().padLeft(2, '0')}',
            ),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: _deadlineMinutes ~/ 60,
                  minute: _deadlineMinutes % 60,
                ),
              );
              if (time != null && mounted) {
                setState(() => _deadlineMinutes = time.hour * 60 + time.minute);
              }
            },
          ),
          ListTile(
            title: const Text('Recurrence anchor'),
            subtitle: Text(
              _anchor?.toIso8601String().split('T').first ?? 'Season start',
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _anchor ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (date != null && mounted) setState(() => _anchor = date);
            },
          ),
          if (_frequency == ChoreFrequency.custom) ...[
            TextButton.icon(
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Add custom date'),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (date != null && mounted) {
                  final value = date.toIso8601String().split('T').first;
                  if (!_customDates.contains(value)) {
                    setState(() => _customDates.add(value));
                  }
                }
              },
            ),
            Wrap(
              children: _customDates
                  .map(
                    (date) => InputChip(
                      label: Text(date),
                      onDeleted: () =>
                          setState(() => _customDates.remove(date)),
                    ),
                  )
                  .toList(),
            ),
          ],
          const _ScheduleNote(),
          if (_apiError != null) ...[
            const SizedBox(height: 16),
            Text(
              _apiError!,
              style: const TextStyle(
                color: AppTheme.red,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_apiError!.toLowerCase().contains('season')) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('Start new season'),
                onPressed: () =>
                    context.push('/houses/${widget.houseId}/seasons/new'),
              ),
            ],
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_editing ? 'Save changes' : 'Create chore'),
          ),
        ],
      ),
    ),
  );

  ChoreTemplate _buildChore() => ChoreTemplate(
    clientRequestId: _requestId,
    asRoutine: _asRoutine,
    deadlineMinutes: _deadlineMinutes,
    recurrenceAnchor: _anchor?.toIso8601String().split('T').first,
    customDates: List.of(_customDates),
    id: widget.initial?.id ?? '',
    name: _name.text,
    description: _description.text,
    karmaPoints: int.parse(_karma.text),
    type: _type,
    frequency: _frequency,
    frequencyValue: _frequency.needsValue
        ? int.tryParse(_frequencyValue.text)
        : null,
    frequencyDays: _days.toList()..sort(),
    difficulty: _difficulty,
    estimatedMinutes: int.tryParse(_estimatedMinutes.text) ?? 30,
  );

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate() ||
        (_frequency == ChoreFrequency.specificDays && _days.isEmpty)) {
      setState(() {});
      return;
    }
    setState(() {
      _saving = true;
      _apiError = null;
    });
    try {
      final repository = ref.read(choreRepositoryProvider);
      var unassigned = 0;
      if (_editing) {
        await repository.updateChore(_buildChore());
      } else {
        final created = await repository.createChore(
          widget.houseId,
          _buildChore(),
        );
        unassigned = created.unassignedCount;
      }
      refreshChoreState(ref, widget.houseId);
      if (mounted) {
        showAppMessage(
          context,
          _editing
              ? 'Chore updated'
              : unassigned > 0
              ? 'Chore created. $unassigned tasks need assignment in Team.'
              : 'Chore created',
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/houses/${widget.houseId}/chores?tab=team');
        }
      }
    } catch (error) {
      if (mounted) setState(() => _apiError = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this chore?'),
        content: const Text(
          'This removes the chore and its generated occurrences. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(choreRepositoryProvider).deleteChore(widget.initial!.id);
      refreshChoreState(ref, widget.houseId);
      if (mounted) {
        context.go('/houses/${widget.houseId}/chores');
        showAppMessage(context, 'Chore deleted');
      }
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ScheduleNote extends StatelessWidget {
  const _ScheduleNote();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppTheme.purple.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Padding(
      padding: EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calendar_month_outlined, color: AppTheme.purple),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'New chores are added to the current schedule. Assignments respect household availability and workload limits.',
            ),
          ),
        ],
      ),
    ),
  );
}
