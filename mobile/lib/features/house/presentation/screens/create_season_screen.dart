import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../home/presentation/providers/home_dashboard_provider.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Start New Season',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_loadingSeasons) ...[
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _selectedCloneSeasonId,
                  decoration: const InputDecoration(
                    labelText: 'Clone from past season (Optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None (Start fresh)'),
                    ),
                    ..._pastSeasons.map(
                      (s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(s['name'] as String),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedCloneSeasonId = v),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Season Name',
                  hintText: 'e.g. Winter Harmony 2026',
                ),
                validator: (v) => v!.trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _allocationMethod,
                decoration: const InputDecoration(
                  labelText: 'Allocation Method',
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Automatic')),
                  DropdownMenuItem(value: 0, child: Text('Manual')),
                ],
                onChanged: (v) => setState(() => _allocationMethod = v!),
              ),
              const SizedBox(height: 24),
              const Text(
                'Active Timeframe',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant
                              .withValues(alpha: .4),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20),
                          const SizedBox(height: 8),
                          const Text(
                            'Starts',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat.yMMMd('en_US').format(_startDate),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
                            if (_endDate.isBefore(d) ||
                                _endDate.isAfter(maxEnd)) {
                              _endDate = maxEnd;
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant
                              .withValues(alpha: .4),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20),
                          const SizedBox(height: 8),
                          const Text(
                            'Ends',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat.yMMMd('en_US').format(_endDate),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () async {
                        final minEnd = _startDate.add(const Duration(days: 1));
                        final maxEnd = DateTime(
                          _startDate.year,
                          _startDate.month + 1,
                          _startDate.day,
                        );
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
                'Each season lasts up to one month (until ${DateFormat('dd/MM/yyyy').format(DateTime(_startDate.year, _startDate.month + 1, _startDate.day))})',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppTheme.muted),
              ),
              if (_apiError != null) ...[
                const SizedBox(height: 24),
                Text(
                  _apiError!,
                  style: const TextStyle(
                    color: AppTheme.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Season'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final maxEnd = DateTime(
      _startDate.year,
      _startDate.month + 1,
      _startDate.day,
    );
    if (!_endDate.isAfter(_startDate)) {
      setState(() => _apiError = 'The end date must be after the start date.');
      return;
    }
    if (_endDate.isAfter(maxEnd) &&
        _endDate.difference(_startDate).inDays > 31) {
      setState(() => _apiError = 'A season can last up to one month.');
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
        await dio.post(
          '/houses/${widget.houseId}/seasons/$_selectedCloneSeasonId/reuse',
          data: payload,
        );
      } else {
        await dio.post('/houses/${widget.houseId}/seasons', data: payload);
      }

      refreshHouseState(ref, houseId: widget.houseId);
      ref.invalidate(homeDashboardProvider(widget.houseId));
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
