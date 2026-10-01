import 'dart:io';

void main() {
  // 1. Update api_endpoints.dart
  var endpointsFile = File('lib/core/network/api_endpoints.dart');
  var endpointsContent = endpointsFile.readAsStringSync();
  if (!endpointsContent.contains('houseSeasons(')) {
    endpointsContent = endpointsContent.replaceFirst(
      '  static const String seasons = \'/seasons\';',
      '  static String houseSeasons(String houseId) => \'/houses/\$houseId/seasons\';\n  static const String seasons = \'/seasons\';'
    );
    endpointsFile.writeAsStringSync(endpointsContent);
  }

  // 2. Create SeasonRemoteDataSource in house feature
  var dsFile = File('lib/features/house/data/datasources/season_remote_data_source.dart');
  dsFile.writeAsStringSync('''
import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';

class SeasonRemoteDataSource {
  const SeasonRemoteDataSource(this._dio);
  final Dio _dio;

  Future<void> createSeason(String houseId, Map<String, dynamic> data) async {
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.houseSeasons(houseId),
      data: data,
    );
  }
}
''');

  // 3. Update house_providers.dart to include season ds
  var provFile = File('lib/features/house/presentation/providers/house_providers.dart');
  var provContent = provFile.readAsStringSync();
  if (!provContent.contains('seasonRemoteDataSourceProvider')) {
    provContent = provContent.replaceFirst(
      'final houseRepositoryProvider = Provider<HouseRepository>((ref) {',
      '''
import '../../data/datasources/season_remote_data_source.dart';

final seasonRemoteDataSourceProvider = Provider<SeasonRemoteDataSource>((ref) {
  return SeasonRemoteDataSource(ref.watch(dioProvider));
});

final houseRepositoryProvider = Provider<HouseRepository>((ref) {'''
    );
    provFile.writeAsStringSync(provContent);
  }

  // 4. Create create_season_screen.dart
  var screenFile = File('lib/features/house/presentation/screens/create_season_screen.dart');
  screenFile.writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../providers/house_providers.dart';

class CreateSeasonScreen extends ConsumerStatefulWidget {
  const CreateSeasonScreen({required this.houseId, super.key});
  final String houseId;

  @override
  ConsumerState<CreateSeasonScreen> createState() => _CreateSeasonScreenState();
}

class _CreateSeasonScreenState extends ConsumerState<CreateSeasonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;
  String? _apiError;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start new season')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Season Name', hintText: 'e.g. Spring Cleaning'),
                validator: (v) => v!.trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('MMM d, yyyy').format(_startDate)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _startDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.arrow_forward),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('MMM d, yyyy').format(_endDate)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _endDate = d);
                      },
                    ),
                  ),
                ],
              ),
              if (_apiError != null) ...[
                const SizedBox(height: 24),
                Text(_apiError!, style: const TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator() : const Text('Create Season'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _apiError = null;
    });
    try {
      final ds = ref.read(seasonRemoteDataSourceProvider);
      await ds.createSeason(widget.houseId, {
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'startDate': _startDate.toUtc().toIso8601String(),
        'endDate': _endDate.toUtc().toIso8601String(),
      });
      refreshHouseState(ref);
      if (mounted) {
        showAppMessage(context, 'Season created!');
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _apiError = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
''');

  // 5. Update app_router.dart
  var routerFile = File('lib/core/router/app_router.dart');
  var routerContent = routerFile.readAsStringSync();
  if (!routerContent.contains('CreateSeasonScreen')) {
    routerContent = routerContent.replaceFirst(
      "import '../../features/house/presentation/screens/qr_join_screen.dart';",
      "import '../../features/house/presentation/screens/qr_join_screen.dart';\nimport '../../features/house/presentation/screens/create_season_screen.dart';"
    );
    routerContent = routerContent.replaceFirst(
      "      GoRoute(\n        path: '/houses/:houseId/achievements',",
      "      GoRoute(\n        path: '/houses/:houseId/seasons/new',\n        builder: (context, state) => CreateSeasonScreen(houseId: state.pathParameters['houseId']!),\n      ),\n      GoRoute(\n        path: '/houses/:houseId/achievements',"
    );
    routerFile.writeAsStringSync(routerContent);
  }

  // 6. Update HouseSettingsScreen to add "Start Season" button
  var settingsFile = File('lib/features/house/presentation/screens/house_settings_screen.dart');
  var settingsContent = settingsFile.readAsStringSync();
  if (!settingsContent.contains("context.push('/houses/\$houseId/seasons/new')")) {
    settingsContent = settingsContent.replaceFirst(
      "          ListTile(\\n            leading: const Icon(Icons.exit_to_app_rounded, color: AppTheme.red),",
      "          ListTile(\\n            leading: const Icon(Icons.add_task_rounded),\\n            title: const Text('Start new season'),\\n            subtitle: const Text('Create a new season for chores and karma'),\\n            onTap: () => context.push('/houses/\$houseId/seasons/new'),\\n          ),\\n          const Divider(),\\n          ListTile(\\n            leading: const Icon(Icons.exit_to_app_rounded, color: AppTheme.red),"
    );
    settingsFile.writeAsStringSync(settingsContent);
  }
}
