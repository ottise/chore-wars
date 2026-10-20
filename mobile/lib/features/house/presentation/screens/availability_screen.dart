import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';

class AvailabilityScreen extends ConsumerStatefulWidget {
  final String houseId, seasonId;
  const AvailabilityScreen({
    super.key,
    required this.houseId,
    required this.seasonId,
  });
  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  final Map<int, List<Map<String, int>>> _slots = {
    for (var d = 0; d < 7; d++) d: [],
  };
  bool _busy = true;
  String? _error;
  String get _endpoint =>
      '/houses/${widget.houseId}/seasons/${widget.seasonId}/availability';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ref.read(dioProvider).get(_endpoint);
      if (!mounted) return;
      final days = Map<String, dynamic>.from(
        result.data['availabilities'] ?? {},
      );
      final slots = Map<String, dynamic>.from(result.data['slots'] ?? {});
      setState(() {
        for (var day = 0; day < 7; day++) {
          final list = slots[day.toString()] as List? ?? [];
          _slots[day] = list
              .map(
                (e) => {
                  'startMinute': (e['startMinute'] as num).toInt(),
                  'endMinute': (e['endMinute'] as num).toInt(),
                },
              )
              .toList();
          if (_slots[day]!.isEmpty && days[day.toString()] == true) {
            _slots[day] = [
              {'startMinute': 0, 'endMinute': 1440},
            ];
          }
        }
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  Future<void> _add(int day) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Available from',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
      helpText: 'Available until',
    );
    if (end == null || !mounted) return;
    final a = start.hour * 60 + start.minute, b = end.hour * 60 + end.minute;
    if (a == b) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start and end must differ.')),
      );
      return;
    }
    void insert(int d, int start, int end) {
      if (end > start) _slots[d]!.add({'startMinute': start, 'endMinute': end});
    }

    setState(() {
      if (b > a) {
        insert(day, a, b);
      } else {
        insert(day, a, 1440);
        insert((day + 1) % 7, 0, b);
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(dioProvider)
          .post(
            _endpoint,
            data: {
              'slots': _slots.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            },
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My availability')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Available hours in Vietnam time. Add one or more intervals per day. Empty days are unavailable. Overnight intervals are split between two days.',
        ),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(onPressed: _load, child: const Text('Reload')),
        ],
        if (_busy) const LinearProgressIndicator(),
        for (final day in [1, 2, 3, 4, 5, 6, 0])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          const [
                            'Sunday',
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday',
                            'Saturday',
                          ][day],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add available interval',
                        onPressed: _busy ? null : () => _add(day),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  if (_slots[day]!.isEmpty) const Text('Unavailable'),
                  Wrap(
                    spacing: 8,
                    children: _slots[day]!
                        .map(
                          (slot) => InputChip(
                            label: Text(
                              '${_time(slot['startMinute']!)} – ${_time(slot['endMinute']!)}',
                            ),
                            onDeleted: _busy
                                ? null
                                : () =>
                                      setState(() => _slots[day]!.remove(slot)),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save availability'),
        ),
      ],
    ),
  );
}
