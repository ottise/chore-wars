import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
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
  int _allocationMethod = 1; // 1 = Automatic, 0 = Manual
  
  bool _saving = false;
  String? _apiError;
  
  List<dynamic> _pastSeasons = [];
  String? _selectedCloneSeasonId;
  bool _loadingSeasons = true;

  @override
  void initState() {
    super.initState();
    _fetchPastSeasons();
  }

  Future<void> _fetchPastSeasons() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/houses/${widget.houseId}/seasons');
      if (mounted) {
        setState(() {
          _pastSeasons = res.data as List<dynamic>;
          _loadingSeasons = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSeasons = false);
    }
  }

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
              if (!_loadingSeasons && _pastSeasons.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedCloneSeasonId,
                  decoration: const InputDecoration(labelText: 'Clone from past season (Optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None (Start fresh)')),
                    ..._pastSeasons.map((s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['name'] as String),
                        ))
                  ],
                  onChanged: (v) => setState(() => _selectedCloneSeasonId = v),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Season Name', hintText: 'e.g. Spring Cleaning'),
                validator: (v) => v!.trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _allocationMethod,
                decoration: const InputDecoration(labelText: 'Allocation Method'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Automatic (AI Generation)')),
                  DropdownMenuItem(value: 0, child: Text('Manual Assignment')),
                ],
                onChanged: (v) => setState(() => _allocationMethod = v!),
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
                        if (d != null) {
                          setState(() {
                            _startDate = d;
                            final maxEnd = DateTime(d.year, d.month + 1, d.day);
                            if (_endDate.isBefore(d) || _endDate.isAfter(maxEnd)) {
                              _endDate = maxEnd;
                            }
                          });
                        }
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
                        final minEnd = _startDate.add(const Duration(days: 1));
                        final maxEnd = DateTime(_startDate.year, _startDate.month + 1, _startDate.day);
                        final initial = _endDate.isBefore(minEnd)
                            ? minEnd
                            : (_endDate.isAfter(maxEnd) ? maxEnd : _endDate);
                        final d = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: minEnd,
                          lastDate: maxEnd,
                        );
                        if (d != null) setState(() => _endDate = d);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Mỗi mùa giải kéo dài tối đa 1 tháng (tối đa đến ${DateFormat('dd/MM/yyyy').format(DateTime(_startDate.year, _startDate.month + 1, _startDate.day))})',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
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

    final maxEnd = DateTime(_startDate.year, _startDate.month + 1, _startDate.day);
    if (!_endDate.isAfter(_startDate)) {
      setState(() => _apiError = 'Ngày kết thúc phải sau ngày bắt đầu.');
      return;
    }
    if (_endDate.isAfter(maxEnd) && _endDate.difference(_startDate).inDays > 31) {
      setState(() => _apiError = 'Một mùa giải chỉ được kéo dài tối đa 1 tháng.');
      return;
    }

    setState(() {
      _saving = true;
      _apiError = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'name': _name.text.trim(),
        'startDate': _startDate.toUtc().toIso8601String(),
        'endDate': _endDate.toUtc().toIso8601String(),
        'allocationMethod': _allocationMethod,
      };

      if (_selectedCloneSeasonId != null) {
        await dio.post('/houses/${widget.houseId}/seasons/$_selectedCloneSeasonId/reuse', data: payload);
      } else {
        await dio.post('/houses/${widget.houseId}/seasons', data: payload);
      }
      
      refreshHouseState(ref, houseId: widget.houseId);
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
