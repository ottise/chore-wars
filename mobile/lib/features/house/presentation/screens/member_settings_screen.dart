import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/house_models.dart';
import '../providers/house_providers.dart';
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

  static const _purple = Color(0xFF7C4DFF);
  static const _purpleSoft = Color(0xFFEDE9FE);

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
                style: const TextStyle(fontWeight: FontWeight.w600),
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

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEDEAF6)),
    ),
    child: child,
  );

  Widget _capacity({
    required String eyebrow,
    required String title,
    required String value,
    required double current,
    required double min,
    required double max,
    required String minLabel,
    required String maxLabel,
    required ValueChanged<double> onChanged,
  }) {
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _purpleSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFC4B5FD)),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFE2E0EC),
            inactiveTrackColor: const Color(0xFFE2E0EC),
            thumbColor: _purple,
            overlayColor: _purple.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Semantics(
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
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              minLabel,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
            Text(
              maxLabel,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final house = ref.watch(houseDetailProvider(widget.houseId)).asData?.value;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final minWeek = math.min(1, _maxChoresPerWeek).toDouble();
    final maxWeek = math.max(40, _maxChoresPerWeek).toDouble();
    final minDay = math.min(15, _maxMinutesPerDay).toDouble();
    final maxDay = math.max(240, _maxMinutesPerDay).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView()
            : !_loaded && _error != null
            ? ErrorView(error: _error!, onRetry: _fetchData)
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/houses/${widget.houseId}');
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Text(
                            'BACK',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      if (house != null || profile != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12),
                              children: [
                                TextSpan(
                                  text: house?.name ?? 'Household',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (profile != null)
                                  TextSpan(
                                    text: ' • ${profile.displayName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'My Settings',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Set your capacity and chore preferences.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _capacity(
                          eyebrow: 'WEEKLY CAPACITY',
                          title: 'Max Chores / Week',
                          value: '$_maxChoresPerWeek tasks',
                          current: _maxChoresPerWeek.toDouble(),
                          min: minWeek,
                          max: maxWeek,
                          minLabel: '${minWeek.toInt()}',
                          maxLabel: '${maxWeek.toInt()}',
                          onChanged: (value) =>
                              setState(() => _maxChoresPerWeek = value.round()),
                        ),
                        const Divider(height: 32, color: Color(0xFFF1F5F9)),
                        _capacity(
                          eyebrow: 'DAILY DEDICATION',
                          title: 'Max Minutes / Day',
                          value: '$_maxMinutesPerDay min',
                          current: _maxMinutesPerDay.toDouble(),
                          min: minDay,
                          max: maxDay,
                          minLabel: '${minDay.toInt()}m',
                          maxLabel: '${maxDay.toInt()}m',
                          onChanged: (value) =>
                              setState(() => _maxMinutesPerDay = value.round()),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3EF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'These limits are used to validate and assign chores. Set your available time slots as well.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chore Preferences',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap a chore to mark as preferred, neutral or disliked.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_chores.isEmpty)
                          const Text(
                            'No chores available to set preferences.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final chore in _chores)
                                _ChorePreferencePill(
                                  name: chore.name,
                                  preference:
                                      _preferences[chore.id] ??
                                      PreferenceType.neutral,
                                  onTap: _isSaving
                                      ? null
                                      : () => _choosePreference(chore),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isSaving
                          ? null
                          : () => context.push(
                              '/houses/${widget.houseId}/seasons/${widget.seasonId}/availability',
                            ),
                      child: const Text(
                        'Edit Availability',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isSaving || !_loaded ? null : _save,
                      child: Text(
                        _isSaving ? 'Saving…' : 'Save Changes',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ChorePreferencePill extends StatelessWidget {
  const _ChorePreferencePill({
    required this.name,
    required this.preference,
    required this.onTap,
  });

  final String name;
  final PreferenceType preference;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isPreferred = preference == PreferenceType.preferred;
    final isDisliked = preference == PreferenceType.disliked;
    final bg = isPreferred
        ? _MemberSettingsScreenState._purpleSoft
        : isDisliked
        ? const Color(0xFFFFF1F2)
        : const Color(0xFFF8F7F4);
    final border = isPreferred
        ? const Color(0xFFC4B5FD)
        : isDisliked
        ? const Color(0xFFFECDD3)
        : const Color(0xFFE5E4DF);
    final textColor = isPreferred
        ? _MemberSettingsScreenState._purple
        : isDisliked
        ? const Color(0xFFE11D48)
        : const Color(0xFF1E293B);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isPreferred || isDisliked
                  ? FontWeight.w700
                  : FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
