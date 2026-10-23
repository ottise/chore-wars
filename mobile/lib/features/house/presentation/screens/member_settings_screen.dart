import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/house_models.dart';
import '../../../chore/domain/entities/chore_models.dart';

class MemberSettingsScreen extends ConsumerStatefulWidget {
  const MemberSettingsScreen({
    required this.houseId,
    required this.seasonId,
    super.key,
  });
  final String houseId, seasonId;
  @override
  ConsumerState<MemberSettingsScreen> createState() =>
      _MemberSettingsScreenState();
}

class _MemberSettingsScreenState extends ConsumerState<MemberSettingsScreen> {
  bool _isLoading = true, _isSaving = false;
  bool _loaded = false;
  String? _error;
  int _maxChoresPerWeek = 10, _maxMinutesPerDay = 120;
  List<ChoreTemplate> _chores = [];
  final Map<String, PreferenceType> _preferences = {};
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _loaded = false;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final responses = await Future.wait([
        dio.get(ApiEndpoints.houseConstraints(widget.houseId)),
        dio.get(ApiEndpoints.housePreferences(widget.houseId)),
        dio.get(ApiEndpoints.houseChores(widget.houseId)),
      ]);
      if (!mounted) return;
      setState(() {
        _maxChoresPerWeek =
            (responses[0].data?['maxChoresPerWeek'] as num?)?.toInt() ?? 10;
        _maxMinutesPerDay =
            (responses[0].data?['maxEffortMinutesPerDay'] as num?)?.toInt() ??
            120;
        _preferences.clear();
        for (final row in responses[1].data as List? ?? []) {
          final preference = MemberPreference.fromJson(
            Map<String, dynamic>.from(row as Map),
          );
          _preferences[preference.choreId] = preference.type;
        }
        _chores = (responses[2].data as List? ?? [])
            .map(
              (row) =>
                  ChoreTemplate.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        _loaded = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_isSaving || !_loaded) return;
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
      ]);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _choosePreference(ChoreTemplate chore) async {
    final selected = await showModalBottomSheet<PreferenceType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                chore.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final item in {
              PreferenceType.preferred: 'Preferred',
              PreferenceType.neutral: 'Neutral',
              PreferenceType.disliked: 'Disliked',
            }.entries)
              ListTile(
                title: Text(item.value),
                selected:
                    (_preferences[chore.id] ?? PreferenceType.neutral) ==
                    item.key,
                onTap: () => Navigator.pop(context, item.key),
              ),
          ],
        ),
      ),
    );
    if (mounted && selected != null) {
      setState(() => _preferences[chore.id] = selected);
    }
  }

  Widget _panel(Widget child) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant
            .withValues(alpha: .35),
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );

  Widget _capacity(
    String eyebrow,
    String title,
    String value,
    double current,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primaryFixed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: colors.onPrimaryFixedVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          label: title,
          child: Slider(
            value: current,
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: value,
            onChanged: _isSaving ? null : onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${min.toInt()}',
              style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
            ),
            Text(
              '${max.toInt()}',
              style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const LoadingView()
          : !_loaded && _error != null
          ? ErrorView(error: _error!, onRetry: _fetchData)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Set your capacity and choose chores that suit you.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _capacity(
                        'WEEKLY CAPACITY',
                        'Max Chores / Week',
                        '$_maxChoresPerWeek tasks',
                        _maxChoresPerWeek.toDouble(),
                        math.min(1, _maxChoresPerWeek).toDouble(),
                        math.max(40, _maxChoresPerWeek).toDouble(),
                        (value) =>
                            setState(() => _maxChoresPerWeek = value.round()),
                      ),
                      const Divider(height: 36),
                      _capacity(
                        'DAILY DEDICATION',
                        'Max Minutes / Day',
                        '$_maxMinutesPerDay min',
                        _maxMinutesPerDay.toDouble(),
                        math.min(15, _maxMinutesPerDay).toDouble(),
                        math.max(240, _maxMinutesPerDay).toDouble(),
                        (value) =>
                            setState(() => _maxMinutesPerDay = value.round()),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'These limits are used to validate and assign chores. Set your available time slots as well.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Chore Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap a chore to mark it as preferred, neutral or disliked.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                _panel(
                  _chores.isEmpty
                      ? const Text('No chores available to set preferences.')
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final chore in _chores)
                              ActionChip(
                                avatar: Icon(
                                  (_preferences[chore.id] ??
                                              PreferenceType.neutral) ==
                                          PreferenceType.preferred
                                      ? Icons.favorite_outline_rounded
                                      : (_preferences[chore.id] ??
                                                PreferenceType.neutral) ==
                                            PreferenceType.disliked
                                      ? Icons.remove_circle_outline
                                      : Icons.cleaning_services_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  '${chore.name}${_preferences[chore.id] == PreferenceType.preferred
                                      ? ' · Preferred'
                                      : _preferences[chore.id] == PreferenceType.disliked
                                      ? ' · Disliked'
                                      : ''}',
                                ),
                                onPressed: _isSaving
                                    ? null
                                    : () => _choosePreference(chore),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => context.push(
                          '/houses/${widget.houseId}/seasons/${widget.seasonId}/availability',
                        ),
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: const Text('Edit Availability'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: colors.error)),
                  ),
              ],
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _isSaving || !_loaded ? null : _save,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(_isSaving ? 'Saving…' : 'Save Changes'),
                ),
              ),
            ),
    );
  }
}
