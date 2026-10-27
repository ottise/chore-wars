import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../house/domain/entities/house_models.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import '../widgets/supplies_ui.dart';

class SupplyScheduleScreen extends ConsumerStatefulWidget {
  const SupplyScheduleScreen({required this.houseId, this.aiDraft, super.key});
  final String houseId;
  final SupplyData? aiDraft;
  @override
  ConsumerState<SupplyScheduleScreen> createState() =>
      _SupplyScheduleScreenState();
}

class _SupplyScheduleScreenState extends ConsumerState<SupplyScheduleScreen> {
  final _items = TextEditingController();
  final _day = TextEditingController(text: '5');
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  String _requestId = const Uuid().v4();
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final a = widget.aiDraft;
    if (a != null) {
      _items.text = a['items']?.toString() ?? '';
      _day.text = (a['day_of_month'] ?? 5).toString();
      _time = TimeOfDay(
        hour: (a['hour'] as num?)?.toInt() ?? 19,
        minute: (a['minute'] as num?)?.toInt() ?? 0,
      );
    }
  }

  @override
  void dispose() {
    _items.dispose();
    _day.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
      if (mounted) ref.invalidate(supplySchedulesProvider(widget.houseId));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner =
        ref.watch(houseDetailProvider(widget.houseId)).asData?.value.myRole ==
        HouseRole.owner;
    return SuppliesPage(
      title: 'Purchase reminders',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Monthly checks in Vietnam time. For days 29–31, shorter months use their last day. Quiet hours: 22:00–08:00. A reminder never places or pays for an order.',
          ),
          const SizedBox(height: 24),
          ref
              .watch(supplySchedulesProvider(widget.houseId))
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => SupplyFailure(
                  e,
                  () => ref.invalidate(supplySchedulesProvider(widget.houseId)),
                ),
                data: (list) => Column(
                  children: [
                    if (list.isEmpty) const Text('No purchase reminders yet.'),
                    for (final s in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SupplySurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['items'].toString(),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Day ${s['dayOfMonth']} · ${s['hour'].toString().padLeft(2, '0')}:${s['minute'].toString().padLeft(2, '0')}',
                              ),
                              Text(
                                'Next check: ${DateFormat('MMM d, yyyy · HH:mm').format(DateTime.parse(s['nextDueAt'].toString()).toUtc().add(const Duration(hours: 7)))} Vietnam time',
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Enabled'),
                                value: s['enabled'] == true,
                                onChanged: owner && !_busy
                                    ? (v) => _run(() async {
                                        await ref
                                            .read(suppliesRepositoryProvider)
                                            .mutate(
                                              '/houses/${widget.houseId}/supply-schedules/${s['id']}',
                                              {
                                                'expectedVersion': s['version'],
                                                'enabled': v,
                                              },
                                              method: 'PATCH',
                                            );
                                      })
                                    : null,
                              ),
                              if (owner)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(() async {
                                          await ref
                                              .read(suppliesRepositoryProvider)
                                              .mutate(
                                                '/houses/${widget.houseId}/supply-schedules/${s['id']}',
                                                {
                                                  'expectedVersion':
                                                      s['version'],
                                                  'enabled': true,
                                                  'snoozedUntil': DateTime.now()
                                                      .toUtc()
                                                      .add(
                                                        const Duration(days: 1),
                                                      )
                                                      .toIso8601String(),
                                                },
                                                method: 'PATCH',
                                              );
                                        }),
                                  child: const Text('Snooze for one day'),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          const SizedBox(height: 24),
          if (owner) ...[
            Text(
              'New monthly reminder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _items,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Supplies to check'),
            ),
            TextField(
              controller: _day,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Day of month (1–31)',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final chosen = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (chosen != null && mounted) {
                        setState(() => _time = chosen);
                      }
                    },
              child: Text('Time: ${_time.format(context)}'),
            ),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await ref.read(suppliesRepositoryProvider).mutate(
                        '/houses/${widget.houseId}/supply-schedules',
                        {
                          'clientRequestId': _requestId,
                          'items': _items.text.trim(),
                          'dayOfMonth': int.tryParse(_day.text) ?? 0,
                          'hour': _time.hour,
                          'minute': _time.minute,
                        },
                      );
                      _requestId = const Uuid().v4();
                    }),
              child: const Text('Save group reminder'),
            ),
          ] else
            const Text(
              'Ask the house owner to approve and save a group reminder.',
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
