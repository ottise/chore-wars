import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chore/domain/entities/chore_models.dart';
import '../../domain/entities/house_models.dart';
import '../providers/house_providers.dart';

class CapacityAvailabilityScreen extends ConsumerStatefulWidget {
  final String houseId;
  final String seasonId;

  const CapacityAvailabilityScreen({
    super.key,
    required this.houseId,
    required this.seasonId,
  });

  @override
  ConsumerState<CapacityAvailabilityScreen> createState() =>
      _CapacityAvailabilityScreenState();
}

class _CapacityAvailabilityScreenState
    extends ConsumerState<CapacityAvailabilityScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  int _maxChoresPerWeek = 20;
  int _maxMinutesPerDay = 120;

  List<ChoreTemplate> _chores = [];
  final Map<String, PreferenceType> _preferences = {};

  final Map<int, List<Map<String, int>>> _slots = {
    for (var d = 0; d < 7; d++) d: [],
  };

  String get _availabilityEndpoint =>
      '/houses/${widget.houseId}/seasons/${widget.seasonId}/availability';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final responses = await Future.wait([
        dio.get(ApiEndpoints.houseConstraints(widget.houseId)),
        dio.get(ApiEndpoints.housePreferences(widget.houseId)),
        dio.get(ApiEndpoints.houseChores(widget.houseId)),
        dio.get(_availabilityEndpoint),
      ]);

      if (!mounted) return;

      final constraintsData = responses[0].data as Map<String, dynamic>?;
      _maxChoresPerWeek =
          (constraintsData?['maxChoresPerWeek'] as num?)?.toInt() ?? 20;
      _maxMinutesPerDay =
          (constraintsData?['maxEffortMinutesPerDay'] as num?)?.toInt() ?? 120;

      _preferences.clear();
      for (final row in responses[1].data as List? ?? []) {
        final pref = MemberPreference.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        _preferences[pref.choreId] = pref.type;
      }

      _chores = (responses[2].data as List? ?? [])
          .map(
            (row) =>
                ChoreTemplate.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();

      final availData = responses[3].data as Map<String, dynamic>? ?? {};
      final days = Map<String, dynamic>.from(availData['availabilities'] ?? {});
      final slots = Map<String, dynamic>.from(availData['slots'] ?? {});

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

      // If user had no slots configured yet, populate initial defaults:
      // Weekdays: 06:00 - 20:00 (14h), Weekends: 08:00 - 16:00 (8h)
      final allEmpty = _slots.values.every((s) => s.isEmpty);
      if (allEmpty) {
        for (var d = 1; d <= 5; d++) {
          _slots[d] = [
            {'startMinute': 360, 'endMinute': 1200},
          ];
        }
        _slots[6] = [
          {'startMinute': 480, 'endMinute': 960},
        ];
        _slots[0] = [
          {'startMinute': 480, 'endMinute': 960},
        ];
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAll({bool popOnSuccess = true}) async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      await Future.wait([
        dio.post(
          ApiEndpoints.houseConstraints(widget.houseId),
          data: {
            'maxChoresPerWeek': _maxChoresPerWeek,
            'maxEffortMinutesPerDay': _maxMinutesPerDay,
          },
        ),
        dio.post(
          ApiEndpoints.housePreferences(widget.houseId),
          data: {
            'preferences': _preferences.entries
                .map(
                  (entry) => {
                    'choreId': entry.key,
                    'type': entry.value.apiValue,
                  },
                )
                .toList(),
          },
        ),
        dio.post(
          _availabilityEndpoint,
          data: {
            'availabilities': {
              for (var d = 0; d < 7; d++)
                d.toString(): (_slots[d]?.isNotEmpty ?? false),
            },
            'slots': _slots.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          },
        ),
      ]);

      if (!mounted) return;
      showAppMessage(
        context,
        popOnSuccess
            ? 'Settings saved successfully'
            : 'Availability window applied and saved',
      );
      if (popOnSuccess) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = apiErrorMessage(e));
        showAppMessage(context, apiErrorMessage(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic> _availabilityPayload(
    Map<int, List<Map<String, int>>> slots,
  ) => {
    'availabilities': {
      for (var day = 0; day < 7; day++)
        day.toString(): (slots[day]?.isNotEmpty ?? false),
    },
    'slots': {
      for (final entry in slots.entries) entry.key.toString(): entry.value,
    },
  };

  Future<void> _saveAvailabilityWindow({
    required Map<int, List<Map<String, int>>> updatedSlots,
    required Map<int, List<Map<String, int>>> previousSlots,
  }) async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        _availabilityEndpoint,
        data: _availabilityPayload(updatedSlots),
      );
      if (!mounted) return;
      setState(() {
        for (final day in updatedSlots.keys) {
          _slots[day] = updatedSlots[day]!
              .map((slot) => Map<String, int>.from(slot))
              .toList();
        }
      });
      showAppMessage(context, 'Availability window applied and saved');
      try {
        final response = await dio.get(_availabilityEndpoint);
        final savedSlots = Map<String, dynamic>.from(
          (response.data as Map<String, dynamic>?)?['slots'] ?? {},
        );
        if (mounted) {
          setState(() {
            for (var day = 0; day < 7; day++) {
              _slots[day] = (savedSlots[day.toString()] as List? ?? [])
                  .map(
                    (slot) => {
                      'startMinute': (slot['startMinute'] as num).toInt(),
                      'endMinute': (slot['endMinute'] as num).toInt(),
                    },
                  )
                  .toList();
            }
          });
        }
      } catch (_) {
        // The save already succeeded; keep the submitted values if refresh fails.
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          for (var day = 0; day < 7; day++) {
            _slots[day] = previousSlots[day] ?? [];
          }
          _error = apiErrorMessage(error);
        });
        showAppMessage(context, apiErrorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int _dayMinutes(int day) {
    final list = _slots[day] ?? [];
    if (list.isEmpty) return 0;
    final sorted = [...list]
      ..sort((a, b) => a['startMinute']!.compareTo(b['startMinute']!));
    var total = 0, start = -1, end = -1;
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
    return total;
  }

  int get _weeklyMinutes {
    var sum = 0;
    for (var d = 0; d < 7; d++) {
      sum += _dayMinutes(d);
    }
    return sum;
  }

  String _formatSlot(Map<String, int> slot) {
    final startM = slot['startMinute'] ?? 0;
    final endM = slot['endMinute'] ?? 1440;
    final sH = (startM ~/ 60).toString().padLeft(2, '0');
    final sMin = (startM % 60).toString().padLeft(2, '0');
    final eH = (endM ~/ 60).toString().padLeft(2, '0');
    final eMin = (endM % 60).toString().padLeft(2, '0');
    return '$sH:$sMin – $eH:$eMin';
  }

  void _editDayRange({
    required String title,
    required List<int> days,
    required int defaultStartMinute,
    required int defaultEndMinute,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        var startMin = defaultStartMinute;
        var endMin = defaultEndMinute;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final sH = (startMin ~/ 60).toString().padLeft(2, '0');
            final sM = (startMin % 60).toString().padLeft(2, '0');
            final eH = (endMin ~/ 60).toString().padLeft(2, '0');
            final eM = (endMin % 60).toString().padLeft(2, '0');
            final durationHrs = ((endMin - startMin) / 60).toStringAsFixed(1);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Edit $title Availability',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Set regular chore windows for selected days ($durationHrs hrs/day).',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: startMin ~/ 60,
                                  minute: startMin % 60,
                                ),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  startMin = picked.hour * 60 + picked.minute;
                                  if (startMin >= endMin)
                                    endMin = startMin + 60;
                                  if (endMin > 1440) endMin = 1440;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start Time',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$sH:$sM',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: endMin ~/ 60,
                                  minute: endMin % 60,
                                ),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  endMin = picked.hour * 60 + picked.minute;
                                  if (endMin <= startMin)
                                    startMin = endMin - 60;
                                  if (startMin < 0) startMin = 0;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'End Time',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$eH:$eM',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C4DFF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (_isSaving) return;
                          final previousSlots = {
                            for (final entry in _slots.entries)
                              entry.key: entry.value
                                  .map((slot) => Map<String, int>.from(slot))
                                  .toList(),
                          };
                          final updatedSlots = {
                            for (final entry in previousSlots.entries)
                              entry.key: entry.value
                                  .map((slot) => Map<String, int>.from(slot))
                                  .toList(),
                          };
                          for (final day in days) {
                            updatedSlots[day] = [
                              {'startMinute': startMin, 'endMinute': endMin},
                            ];
                          }
                          setState(() {
                            for (final d in days) {
                              _slots[d] = updatedSlots[d]!;
                            }
                          });
                          Navigator.pop(ctx);
                          await _saveAvailabilityWindow(
                            updatedSlots: updatedSlots,
                            previousSlots: previousSlots,
                          );
                        },
                        child: const Text(
                          'Apply Window',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _choosePreference(ChoreTemplate chore) {
    showModalBottomSheet<PreferenceType>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  chore.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1ECE7)),
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('✨', style: TextStyle(fontSize: 16)),
                  ),
                ),
                title: const Text(
                  'Preferred',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Algorithm gives you priority for this task',
                ),
                trailing: (_preferences[chore.id] == PreferenceType.preferred)
                    ? const Icon(Icons.check_rounded, color: Color(0xFF059669))
                    : null,
                onTap: () {
                  setState(
                    () => _preferences[chore.id] = PreferenceType.preferred,
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.horizontal_rule_rounded,
                    color: Color(0xFF64748B),
                    size: 16,
                  ),
                ),
                title: const Text(
                  'Neutral',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Standard rotation among roommates'),
                trailing:
                    (_preferences[chore.id] == PreferenceType.neutral ||
                        _preferences[chore.id] == null)
                    ? const Icon(Icons.check_rounded, color: Color(0xFF475569))
                    : null,
                onTap: () {
                  setState(
                    () => _preferences[chore.id] = PreferenceType.neutral,
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFDC2626),
                    size: 16,
                  ),
                ),
                title: const Text(
                  'Avoid (Disliked)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Assigned only when nobody else is free'),
                trailing: (_preferences[chore.id] == PreferenceType.disliked)
                    ? const Icon(Icons.check_rounded, color: Color(0xFFDC2626))
                    : null,
                onTap: () {
                  setState(
                    () => _preferences[chore.id] = PreferenceType.disliked,
                  );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddPreferenceModal() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Select Chore to Configure',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            if (_chores.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No household chores found.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _chores.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFF1ECE7)),
                  itemBuilder: (ctx, idx) {
                    final c = _chores[idx];
                    final currentPref =
                        _preferences[c.id] ?? PreferenceType.neutral;
                    return ListTile(
                      title: Text(
                        c.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      trailing: _buildPreferenceBadge(currentPref),
                      onTap: () {
                        Navigator.pop(ctx);
                        _choosePreference(c);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceBadge(PreferenceType type) {
    switch (type) {
      case PreferenceType.preferred:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Preferred ✨',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF059669),
            ),
          ),
        );
      case PreferenceType.disliked:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Avoid ✕',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFDC2626),
            ),
          ),
        );
      case PreferenceType.neutral:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Neutral',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final house = ref.watch(houseDetailProvider(widget.houseId)).value;
    final user = ref.watch(userProfileProvider).value;
    final houseName = house?.name.isNotEmpty == true ? house!.name : 'The Gang';
    final memberName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : 'Me';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(houseName, memberName),
            Expanded(
              child: _isLoading
                  ? const LoadingWidget()
                  : _error != null && _chores.isEmpty
                  ? ErrorState(error: _error!, onRetry: _loadAll)
                  : _buildMainContent(),
            ),
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String houseName, String memberName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 17,
                    color: Color(0xFF1E293B),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1ECE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$houseName · $memberName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Capacity & Availability',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Set your chore limits, favorite tasks, and weekly free time.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Active - Balanced auto-sync',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Algorithm ON',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C4DFF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        _buildWorkloadLimitsCard(),
        const SizedBox(height: 16),
        _buildChorePreferencesCard(),
        const SizedBox(height: 16),
        _buildWeeklyScheduleCard(),
      ],
    );
  }

  Widget _buildWorkloadLimitsCard() {
    final dailyChoresApprox = (_maxChoresPerWeek / 7).toStringAsFixed(0);
    final hoursPerDay = (_maxMinutesPerDay / 60).toStringAsFixed(1);

    String workloadText = 'Balanced workload';
    Color workloadColor = const Color(0xFF10B981);
    if (_maxMinutesPerDay < 60) {
      workloadText = 'Light workload';
      workloadColor = const Color(0xFF0D9488);
    } else if (_maxMinutesPerDay > 180) {
      workloadText = 'High workload';
      workloadColor = const Color(0xFFD97706);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1ECE7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF7C4DFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workload Limits',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Target chore distribution per week',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Weekly Limits',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C4DFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF9F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1ECE7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'CHORE LIMIT',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Max 40',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$_maxChoresPerWeek',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7C4DFF),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Flexible(
                            child: Text(
                              'chores / wk',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '~$dailyChoresApprox chores / day',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: const Color(0xFF7C4DFF),
                          inactiveTrackColor: const Color(0xFFEDE9FE),
                          thumbColor: const Color(0xFF7C4DFF),
                        ),
                        child: Slider(
                          value: _maxChoresPerWeek.clamp(1, 40).toDouble(),
                          min: 1,
                          max: 40,
                          onChanged: (val) {
                            setState(() => _maxChoresPerWeek = val.round());
                          },
                        ),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1 min',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            '40 max',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF9F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1ECE7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'TIME DEDICATION',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_maxMinutesPerDay}m',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            hoursPerDay,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7C4DFF),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Flexible(
                            child: Text(
                              'hrs / day',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        workloadText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: workloadColor,
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: const Color(0xFF7C4DFF),
                          inactiveTrackColor: const Color(0xFFEDE9FE),
                          thumbColor: const Color(0xFF7C4DFF),
                        ),
                        child: Slider(
                          value: _maxMinutesPerDay.clamp(30, 240).toDouble(),
                          min: 30,
                          max: 240,
                          divisions: 14,
                          onChanged: (val) {
                            setState(() => _maxMinutesPerDay = val.round());
                          },
                        ),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '0.5h',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            '4h max',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEDE9FE)),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                      children: [
                        const TextSpan(
                          text: 'The algorithm will assign chores strictly within your ',
                        ),
                        TextSpan(
                          text: '$_maxChoresPerWeek chores',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const TextSpan(text: ' & '),
                        TextSpan(
                          text: '$hoursPerDay hrs/day',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const TextSpan(text: ' boundary.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChorePreferencesCard() {
    final preferred = <ChoreTemplate>[];
    final neutral = <ChoreTemplate>[];
    final avoid = <ChoreTemplate>[];

    for (final c in _chores) {
      final pref = _preferences[c.id] ?? PreferenceType.neutral;
      if (pref == PreferenceType.preferred) {
        preferred.add(c);
      } else if (pref == PreferenceType.disliked) {
        avoid.add(c);
      } else {
        neutral.add(c);
      }
    }

    final configuredCount = preferred.length + avoid.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1ECE7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chore Preferences',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Prioritize your favorite and avoid disliked tasks',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$configuredCount configured',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPreferenceGroup(
            label: 'PREFERRED',
            labelBg: const Color(0xFFECFDF5),
            labelColor: const Color(0xFF059669),
            items: preferred,
            emptyText: 'No preferred chores selected',
            chipBg: const Color(0xFFECFDF5),
            chipBorder: const Color(0xFFA7F3D0),
            chipColor: const Color(0xFF047857),
            suffix: ' ✨',
            showDot: true,
            dotColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 10),
          _buildPreferenceGroup(
            label: 'NEUTRAL',
            labelBg: const Color(0xFFF1F5F9),
            labelColor: const Color(0xFF475569),
            items: neutral.take(3).toList(),
            emptyText: 'No neutral chores',
            chipBg: const Color(0xFFF8FAFC),
            chipBorder: const Color(0xFFE2E8F0),
            chipColor: const Color(0xFF475569),
            suffix: '',
            showDot: false,
          ),
          const SizedBox(height: 10),
          _buildPreferenceGroup(
            label: 'AVOID',
            labelBg: const Color(0xFFFEF2F2),
            labelColor: const Color(0xFFDC2626),
            items: avoid,
            emptyText: 'No disliked chores selected',
            chipBg: const Color(0xFFFEF2F2),
            chipBorder: const Color(0xFFFECACA),
            chipColor: const Color(0xFFB91C1C),
            suffix: ' ✕',
            showDot: true,
            dotColor: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: _openAddPreferenceModal,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(
                  color: Color(0xFFC7D2FE),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 16, color: Color(0xFF7C4DFF)),
                  SizedBox(width: 6),
                  Text(
                    'Add Chore Preference',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C4DFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceGroup({
    required String label,
    required Color labelBg,
    required Color labelColor,
    required List<ChoreTemplate> items,
    required String emptyText,
    required Color chipBg,
    required Color chipBorder,
    required Color chipColor,
    required String suffix,
    required bool showDot,
    Color? dotColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 82,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    emptyText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in items)
                      InkWell(
                        onTap: () => _choosePreference(c),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: chipBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDot && dotColor != null) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                '${c.name}$suffix',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: chipColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildWeeklyScheduleCard() {
    final freeHours = (_weeklyMinutes / 60).toStringAsFixed(0);

    // Weekday hours (Mon-Fri = 1, 2, 3, 4, 5)
    final weekdayMinutesDaily = _dayMinutes(1);
    final weekdayHours = (weekdayMinutesDaily / 60).toStringAsFixed(0);
    final weekdaySlot = _slots[1]?.firstOrNull;
    final weekdayRangeStr = weekdaySlot != null
        ? _formatSlot(weekdaySlot)
        : '06:00 – 20:00';

    // Weekend hours (Sat-Sun = 6, 0)
    final weekendMinutesDaily = _dayMinutes(6);
    final weekendHours = (weekendMinutesDaily / 60).toStringAsFixed(0);
    final weekendSlot = _slots[6]?.firstOrNull;
    final weekendRangeStr = weekendSlot != null
        ? _formatSlot(weekendSlot)
        : '08:00 – 16:00';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1ECE7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Weekly Schedule',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'GMT+7',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Your available time windows for chores',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$freeHours hrs free',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C4DFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final d in [
                (1, 'MON'),
                (2, 'TUE'),
                (3, 'WED'),
                (4, 'THU'),
                (5, 'FRI'),
                (6, 'SAT'),
                (0, 'SUN'),
              ])
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: d.$1 >= 1 && d.$1 <= 5
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: d.$1 >= 1 && d.$1 <= 5
                            ? const Color(0xFFE0E7FF)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          d.$2,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: d.$1 >= 1 && d.$1 <= 5
                                ? const Color(0xFF4338CA)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: d.$1 >= 1 && d.$1 <= 5
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_dayMinutes(d.$1) ~/ 60}h',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: d.$1 >= 1 && d.$1 <= 5
                                ? const Color(0xFF3730A3)
                                : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildScheduleWindowTile(
            title: 'Weekdays (Mon – Fri)',
            dailyHoursText: '${weekdayHours}h/day',
            timeRangeText: '$weekdayRangeStr • Recurring',
            onEdit: () => _editDayRange(
              title: 'Weekdays (Mon – Fri)',
              days: [1, 2, 3, 4, 5],
              defaultStartMinute: weekdaySlot?['startMinute'] ?? 360,
              defaultEndMinute: weekdaySlot?['endMinute'] ?? 1200,
            ),
          ),
          const SizedBox(height: 8),
          _buildScheduleWindowTile(
            title: 'Weekend (Sat – Sun)',
            dailyHoursText: '${weekendHours}h/day',
            timeRangeText: '$weekendRangeStr • Recurring',
            onEdit: () => _editDayRange(
              title: 'Weekend (Sat – Sun)',
              days: [6, 0],
              defaultStartMinute: weekendSlot?['startMinute'] ?? 480,
              defaultEndMinute: weekendSlot?['endMinute'] ?? 960,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleWindowTile({
    required String title,
    required String dailyHoursText,
    required String timeRangeText,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1ECE7)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Color(0xFF64748B),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dailyHoursText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  timeRangeText,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 12, color: Color(0xFF475569)),
                SizedBox(width: 4),
                Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF1ECE7))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _isSaving ? null : () => _saveAll(popOnSuccess: true),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
