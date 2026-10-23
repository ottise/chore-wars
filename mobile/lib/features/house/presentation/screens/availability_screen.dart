import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  bool _loaded = false;
  String? _error;
  String get _endpoint =>
      '/houses/${widget.houseId}/seasons/${widget.seasonId}/availability';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _loaded = false;
    });
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
        _loaded = true;
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
    if (_busy || !_loaded) return;
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

  int get _weeklyMinutes {
    var total = 0;
    for (final slots in _slots.values) {
      final sorted = [...slots]
        ..sort((a, b) => a['startMinute']!.compareTo(b['startMinute']!));
      var start = -1, end = -1;
      for (final slot in sorted) {
        if (start < 0) {
          start = slot['startMinute']!;
          end = slot['endMinute']!;
        } else if (slot['startMinute']! <= end) {
          if (slot['endMinute']! > end) end = slot['endMinute']!;
        } else {
          total += end - start;
          start = slot['startMinute']!;
          end = slot['endMinute']!;
        }
      }
      if (start >= 0) total += end - start;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My availability',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: .35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: const Text(
                          'Vietnam Time (GMT+7)',
                          style: TextStyle(fontSize: 10),
                        ),
                        avatar: const Icon(Icons.public_outlined, size: 14),
                        backgroundColor: colors.primaryFixed,
                      ),
                      Chip(
                        label: const Text(
                          'Weekly',
                          style: TextStyle(fontSize: 10),
                        ),
                        avatar: const Icon(Icons.repeat_rounded, size: 14),
                        backgroundColor: colors.tertiaryFixed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Available hours in Vietnam time (GMT+7). Add intervals for each day. Empty days are unavailable. Overnight intervals are split across two days.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: TextStyle(color: colors.error)),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Reload'),
                  ),
                ],
              ),
            ),
          if (_loaded)
            for (final day in [1, 2, 3, 4, 5, 6, 0])
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant
                          .withValues(alpha: .35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_slots[day]!.isNotEmpty)
                              Text(
                                '${_slots[day]!.length} slots',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Add available interval',
                              style: IconButton.styleFrom(
                                backgroundColor: _slots[day]!.isEmpty
                                    ? colors.surfaceContainerLow
                                    : colors.primary,
                                foregroundColor: _slots[day]!.isEmpty
                                    ? colors.onSurface
                                    : colors.onPrimary,
                              ),
                              onPressed: _busy ? null : () => _add(day),
                              icon: const Icon(Icons.add_rounded, size: 20),
                            ),
                          ],
                        ),
                        if (_slots[day]!.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Unavailable',
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final slot in _slots[day]!)
                              InputChip(
                                backgroundColor: colors.primaryFixed,
                                labelStyle: TextStyle(
                                  color: colors.onPrimaryFixedVariant,
                                  fontSize: 11,
                                ),
                                label: Text(
                                  '${_time(slot['startMinute']!)} – ${_time(slot['endMinute']!)}',
                                ),
                                onDeleted: _busy
                                    ? null
                                    : () => setState(
                                        () => _slots[day]!.remove(slot),
                                      ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          if (_loaded)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => context.push(
                        '/houses/${widget.houseId}/seasons/${widget.seasonId}/member-settings',
                      ),
                child: const Text('Chore preferences & capacity'),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: .35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Total',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _loaded
                              ? '${(_weeklyMinutes / 60).toStringAsFixed(1)} hrs available'
                              : '—',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _busy || !_loaded ? null : _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(_busy && _loaded ? 'Saving…' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
