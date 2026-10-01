import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/chore_models.dart';
import '../providers/chore_providers.dart';

class ChoreFormScreen extends ConsumerStatefulWidget {
  const ChoreFormScreen({required this.houseId, this.initial, super.key});
  final String houseId;
  final ChoreTemplate? initial;

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
              icon: Icons.search_off_rounded,
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
  bool _saving = false;
  String? _apiError;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final chore = widget.initial;
    _name = TextEditingController(text: chore?.name ?? '');
    _description = TextEditingController(text: chore?.description ?? '');
    _karma = TextEditingController(text: chore?.karmaPoints.toString() ?? '');
    _frequencyValue = TextEditingController(
      text: chore?.frequencyValue?.toString() ?? '',
    );
    _type = chore?.type ?? ChoreType.normal;
    _frequency = chore?.frequency ?? ChoreFrequency.daily;
    _days = {...?chore?.frequencyDays};
    _difficulty = chore?.difficulty ?? ChoreEffort.medium;
    _estimatedMinutes = TextEditingController(text: (chore?.estimatedMinutes ?? 30).toString());
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
      title: Text(_editing ? 'Edit chore' : 'Create chore'),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Add a clear finish line for this task',
            ),
          ),
          const SizedBox(height: 24),
          Text('Chore type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ChoreType>(
            segments: const [
              ButtonSegment(
                value: ChoreType.normal,
                icon: Icon(Icons.repeat_rounded),
                label: Text('Normal'),
              ),
              ButtonSegment(
                value: ChoreType.bonus,
                icon: Icon(Icons.auto_awesome_rounded),
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
                child: TextFormField(
                  controller: _estimatedMinutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    suffixText: 'min',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    return parsed == null || parsed <= 0
                        ? 'Invalid'
                        : null;
                  },
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
          if (_frequency == ChoreFrequency.specificDays) ...[
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
          const _ScheduleNote(),
          if (_apiError != null) ...[
            const SizedBox(height: 16),
            Text(
              _apiError!,
              style: const TextStyle(color: AppTheme.red, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (_apiError!.toLowerCase().contains('season')) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Start new season'),
                onPressed: () => context.push('/houses/${widget.houseId}/seasons/new'),
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
      if (_editing) {
        await repository.updateChore(_buildChore());
      } else {
        await repository.createChore(widget.houseId, _buildChore());
      }
      refreshChoreState(ref, widget.houseId);
      if (mounted) {
        showAppMessage(context, _editing ? 'Chore updated' : 'Chore created');
        context.pop();
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
          'This removes the routine and any generated occurrences tied to it. This cannot be undone.',
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
              'Deadline and time window are set when this routine is generated into the active season schedule.',
            ),
          ),
        ],
      ),
    ),
  );
}
