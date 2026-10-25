import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_page_frame.dart';

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
  Widget build(BuildContext context) => AppPageFrame(builder: _buildScreen);

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      appBar: AppPageBar(title: 'Start New Season', centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_loadingSeasons) ...[
                _field(
                  context,
                  'Clone from past season (optional)',
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _selectedCloneSeasonId,
                    decoration: const InputDecoration(),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('None (Start fresh)'),
                      ),
                      ..._pastSeasons.map(
                        (season) => DropdownMenuItem(
                          value: season['id'] as String,
                          child: Text(season['name'] as String),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedCloneSeasonId = value),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _field(
                context,
                'Season Name',
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Winter Harmony 2026',
                  ),
                  validator: (value) =>
                      value!.trim().isEmpty ? 'Enter a name' : null,
                ),
              ),
              const SizedBox(height: 16),
              _field(
                context,
                'Allocation Method',
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _allocationMethod,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Automatic')),
                    DropdownMenuItem(value: 0, child: Text('Manual')),
                  ],
                  onChanged: (value) =>
                      setState(() => _allocationMethod = value!),
                ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant
                              .withValues(alpha: .4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryFixed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_today_outlined,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Starts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat.yMMMd('en_US').format(_startDate),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
                    Icons.arrow_forward_outlined,
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant
                              .withValues(alpha: .4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryFixed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_today_outlined,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ends',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat.yMMMd('en_US').format(_endDate),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
                    fontWeight: FontWeight.w600,
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

  Widget _field(BuildContext context, String label, Widget child) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Theme(
            data: theme.copyWith(
              inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.primary),
                ),
              ),
            ),
            child: Semantics(label: label, child: child),
          ),
        ],
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
