import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../domain/entities/house_models.dart';
import '../../../chore/domain/entities/chore_models.dart';
import '../providers/house_providers.dart';

class MemberSettingsScreen extends ConsumerStatefulWidget {
  const MemberSettingsScreen({
    required this.houseId,
    required this.seasonId,
    super.key,
  });

  final String houseId;
  final String seasonId;

  @override
  ConsumerState<MemberSettingsScreen> createState() => _MemberSettingsScreenState();
}

class _MemberSettingsScreenState extends ConsumerState<MemberSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Availability
  final Map<int, bool> _availability = {
    0: true, 1: true, 2: true, 3: true,
    4: true, 5: true, 6: true,
  };
  final _days = [
    (1, 'Monday'), (2, 'Tuesday'), (3, 'Wednesday'),
    (4, 'Thursday'), (5, 'Friday'), (6, 'Saturday'), (0, 'Sunday'),
  ];

  // Constraints
  int _maxChoresPerWeek = 10;
  int _maxMinutesPerDay = 120;

  // Preferences
  List<ChoreTemplate> _chores = [];
  Map<String, PreferenceType> _preferences = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final dio = ref.read(dioProvider);
      
      final futures = await Future.wait([
        dio.get(ApiEndpoints.houseConstraints(widget.houseId)),
        dio.get(ApiEndpoints.housePreferences(widget.houseId)),
        dio.get(ApiEndpoints.houseChores(widget.houseId)),
        dio.get(ApiEndpoints.seasonAvailability(widget.houseId, widget.seasonId)),
      ]);

      final constraintsData = futures[0].data;
      if (constraintsData != null) {
        _maxChoresPerWeek = constraintsData['maxChoresPerWeek'] ?? 10;
        _maxMinutesPerDay = constraintsData['maxEffortMinutesPerDay'] ?? 120;
      }

      final prefsData = futures[1].data as List<dynamic>? ?? [];
      for (var p in prefsData) {
        final pref = MemberPreference.fromJson(p);
        _preferences[pref.choreId] = pref.type;
      }

      final choresData = futures[2].data as List<dynamic>? ?? [];
      _chores = choresData.map((c) => ChoreTemplate.fromJson(c)).toList();

      final availData = futures[3].data['availabilities'] as Map<String, dynamic>? ?? {};
      availData.forEach((key, value) {
        final dayInt = int.tryParse(key);
        if (dayInt != null && _availability.containsKey(dayInt)) {
          _availability[dayInt] = value as bool;
        }
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      
      // Save Availability
      final Map<String, bool> availabilityPayload = {};
      _availability.forEach((key, value) {
        availabilityPayload[key.toString()] = value;
      });

      // Save Constraints
      final constraintsPayload = {
        'maxChoresPerWeek': _maxChoresPerWeek,
        'maxEffortMinutesPerDay': _maxMinutesPerDay,
      };

      // Save Preferences
      final prefsPayload = _preferences.entries.map((e) => {
        'choreId': e.key,
        'type': e.value.apiValue,
      }).toList();

      await Future.wait([
        dio.post(ApiEndpoints.seasonAvailability(widget.houseId, widget.seasonId), 
                 data: {'availabilities': availabilityPayload}),
        dio.post(ApiEndpoints.houseConstraints(widget.houseId), 
                 data: constraintsPayload),
        dio.post(ApiEndpoints.housePreferences(widget.houseId), 
                 data: prefsPayload),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionTitle('📅 Availability', 'Days you can do chores.'),
          const SizedBox(height: 16),
          _buildAvailabilitySection(),
          
          const SizedBox(height: 32),
          _buildSectionTitle('⚙️ Constraints', 'Your maximum workload limits.'),
          const SizedBox(height: 16),
          _buildConstraintsSection(),
          
          const SizedBox(height: 32),
          _buildSectionTitle('❤️ Preferences', 'Your chore preferences.'),
          const SizedBox(height: 16),
          _buildPreferencesSection(),

          const SizedBox(height: 48),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted)),
      ],
    );
  }

  Widget _buildAvailabilitySection() {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _days.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            SwitchListTile(
              title: Text(_days[i].$2, style: const TextStyle(fontWeight: FontWeight.w500)),
              value: _availability[_days[i].$1]!,
              onChanged: (val) => setState(() => _availability[_days[i].$1] = val),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConstraintsSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Max Chores / Week', style: TextStyle(fontWeight: FontWeight.w500)),
                Text('$_maxChoresPerWeek', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.purple)),
              ],
            ),
            Slider(
              value: _maxChoresPerWeek.toDouble(),
              min: 1, max: 30, divisions: 29,
              onChanged: (val) => setState(() => _maxChoresPerWeek = val.round()),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Max Minutes / Day', style: TextStyle(fontWeight: FontWeight.w500)),
                Text('$_maxMinutesPerDay', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.purple)),
              ],
            ),
            Slider(
              value: _maxMinutesPerDay.toDouble(),
              min: 15, max: 300, divisions: 19, // 15 min increments
              onChanged: (val) => setState(() => _maxMinutesPerDay = val.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    if (_chores.isEmpty) {
      return const Text('No chores available to set preferences.');
    }
    
    return Column(
      children: _chores.map((chore) {
        final currentPref = _preferences[chore.id] ?? PreferenceType.neutral;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chore.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<PreferenceType>(
                      segments: const [
                        ButtonSegment(value: PreferenceType.disliked, icon: Text('😞')),
                        ButtonSegment(value: PreferenceType.neutral, icon: Text('😐')),
                        ButtonSegment(value: PreferenceType.preferred, icon: Text('😍')),
                      ],
                      selected: {currentPref},
                      onSelectionChanged: (set) {
                        setState(() => _preferences[chore.id] = set.first);
                      },
                      showSelectedIcon: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
