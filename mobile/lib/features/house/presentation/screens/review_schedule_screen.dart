import '../widgets/household_summary_sections.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/house_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/house_models.dart';

class ReviewScheduleScreen extends ConsumerStatefulWidget {
  final String houseId, seasonId;
  const ReviewScheduleScreen({
    super.key,
    required this.houseId,
    required this.seasonId,
  });
  @override
  ConsumerState<ReviewScheduleScreen> createState() =>
      _ReviewScheduleScreenState();
}

class _ReviewScheduleScreenState extends ConsumerState<ReviewScheduleScreen> {
  bool _busy = true;
  String? _error;
  Map<String, dynamic>? _season;
  Map<String, dynamic> _summary = {};
  List<dynamic> _occurrences = [];
  String get _base => '/houses/${widget.houseId}/seasons/${widget.seasonId}';
  bool get _draft => _season?['status'] == 0 || _season?['status'] == 'DRAFT';
  bool get _owner =>
      ref.watch(houseDetailProvider(widget.houseId)).asData?.value.myRole ==
      HouseRole.owner;
  bool get _confirmed {
    final user = ref.watch(userProfileProvider).asData?.value.id;
    return (_season?['confirmations'] as List? ?? []).any(
      (c) =>
          c['userId'] == user &&
          (c['status'] == 1 || c['status'] == 'CONFIRMED'),
    );
  }

  bool get _reviewing =>
      _season?['status'] == 1 || _season?['status'] == 'REVIEWING';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get('/houses/${widget.houseId}/seasons'),
        dio.get('$_base/occurrences'),
        dio.get('$_base/workload-summary'),
      ]);
      if (!mounted) return;
      setState(() {
        _season = Map<String, dynamic>.from(
          (results[0].data as List).firstWhere(
            (s) => s['id'] == widget.seasonId,
          ),
        );
        _occurrences = List.from(results[1].data as List);
        _summary = Map<String, dynamic>.from(results[2].data);
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(String action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? reason;
      if (action == 'reject') {
        final input = TextEditingController();
        try {
          reason = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Why reject this schedule?'),
              content: TextField(
                controller: input,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, input.text.trim()),
                  child: const Text('Reject'),
                ),
              ],
            ),
          );
        } finally {
          input.dispose();
        }
        if (reason == null || reason.isEmpty) return;
      }
      await ref
          .read(dioProvider)
          .post(
            '$_base/$action',
            data: action == 'confirm'
                ? {'scheduleRevision': _season?['scheduleRevision']}
                : action == 'reject'
                ? {'reason': reason}
                : null,
          );
      if (!mounted) return;
      refreshHouseState(ref, houseId: widget.houseId);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(Map<String, dynamic> occurrence) async {
    final members = await ref.read(houseMembersProvider(widget.houseId).future);
    if (!mounted) return;
    final user = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Assign to'),
        children: [
          for (final member in members.where((m) => m.isActive))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, member.userId),
              child: Text(member.displayName),
            ),
        ],
      ),
    );
    if (user == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dioProvider)
          .put(
            '$_base/occurrences/${occurrence['id']}/assign',
            data: {'assigneeId': user},
          );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importRoutine() async {
    try {
      final result = await ref
          .read(dioProvider)
          .get('/houses/${widget.houseId}/chores');
      if (!mounted) return;
      final routines = (result.data as List)
          .where((item) => item['seasonId'] == null)
          .toList();
      final id = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Import routine snapshot'),
          children: [
            if (routines.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Create a reusable routine first.'),
              ),
            for (final routine in routines)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(context, routine['id'].toString()),
                child: Text(routine['name'].toString()),
              ),
          ],
        ),
      );
      if (id == null || !mounted) return;
      setState(() => _busy = true);
      await ref.read(dioProvider).post('$_base/routines/$id');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _signed(String id) => (_season?['confirmations'] as List? ?? []).any(
    (row) =>
        row['userId'] == id &&
        (row['status'] == 1 || row['status'] == 'CONFIRMED'),
  );

  bool _rejected(String id) => (_season?['confirmations'] as List? ?? []).any(
    (row) =>
        row['userId'] == id &&
        (row['status'] == 2 || row['status'] == 'REJECTED'),
  );

  Widget _panel(Widget child) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant
            .withValues(alpha: .35),
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _status(String label, bool signed) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: label == 'Rejected'
          ? Theme.of(context).colorScheme.errorContainer
          : signed
          ? AppTheme.successContainer
          : Theme.of(context).colorScheme.tertiaryFixed,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: label == 'Rejected'
            ? Theme.of(context).colorScheme.onErrorContainer
            : signed
            ? AppTheme.green
            : Theme.of(context).colorScheme.onTertiaryFixedVariant,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Household Summary'),
        actions: [
          IconButton(
            tooltip: 'Refresh schedule',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Schedule'),
            Tab(text: 'Spending & Payments'),
            Tab(text: 'Chore Completion'),
            Tab(text: 'Member Contributions'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _schedule(context),
          for (var section = 1; section <= 3; section++)
            HouseholdSummarySection(
              houseId: widget.houseId,
              seasonId: widget.seasonId,
              section: section,
            ),
        ],
      ),
    ),
  );

  Widget _schedule(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final me = ref.watch(userProfileProvider).asData?.value.id;
    final members = _summary['members'] as List? ?? [];
    final totalKarma = members.fold<num>(
      0,
      (total, row) => total + ((row['totalAssignedKarma'] as num?) ?? 0),
    );
    final signedCount = members
        .where((row) => _signed(row['userId'].toString()))
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, style: TextStyle(color: colors.error)),
          ),
        if (_season != null) ...[
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text(
                        '${_season!['name'] ?? 'Season'} · Revision ${_season!['scheduleRevision'] ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onPrimaryFixedVariant,
                        ),
                      ),
                      backgroundColor: colors.primaryFixed,
                    ),
                    _status(
                      '$signedCount/${members.length} approvals',
                      signedCount == members.length && members.isNotEmpty,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'All active members must approve the same schedule revision before the season starts.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (_season!['lastRejectionReason'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Revision requested: ${_season!['lastRejectionReason']}',
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'MEMBER WORKLOAD & KARMA',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${members.length} members',
                style: TextStyle(fontSize: 12, color: colors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final member in members)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _panel(
                Builder(
                  builder: (context) {
                    final id = member['userId'].toString();
                    final name = member['displayName']?.toString() ?? 'Member';
                    final karma = (member['totalAssignedKarma'] as num?) ?? 0;
                    final share = totalKarma > 0 ? karma / totalKarma : 0.0;
                    final signed = _signed(id);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: id == me
                                    ? colors.primaryContainer
                                    : colors.tertiaryFixed,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                name.isEmpty
                                    ? '?'
                                    : name.characters.first.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: id == me
                                      ? colors.onPrimaryContainer
                                      : colors.onTertiaryFixedVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$name${id == me ? ' · You' : ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$karma Karma · ${member['totalEstimatedMinutes'] ?? 0} min',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            _status(
                              signed
                                  ? 'Approved'
                                  : _rejected(id)
                                  ? 'Rejected'
                                  : 'Pending',
                              signed,
                            ),
                          ],
                        ),
                        const Divider(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Chore Share ${(share * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              '${member['totalChores'] ?? 0} tasks',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: share.clamp(0.0, 1.0).toDouble(),
                            minHeight: 6,
                            color: id == me
                                ? colors.primaryContainer
                                : colors.tertiary,
                            backgroundColor: colors.surfaceContainerHigh,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          for (final warning in _summary['warnings'] as List? ?? [])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(warning.toString()),
            ),
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'MEMBER CONFIRMATIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$signedCount/${members.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final member in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              member['displayName']?.toString() ?? 'Member',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          _status(
                            _signed(member['userId'].toString())
                                ? 'Confirmed'
                                : _rejected(member['userId'].toString())
                                ? 'Rejected'
                                : 'Awaiting',
                            _signed(member['userId'].toString()),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_reviewing) ...[
            FilledButton.icon(
              onPressed: _busy || _confirmed || _error != null
                  ? null
                  : () => _act('confirm'),
              icon: const Icon(Icons.done_all_outlined, size: 18),
              label: Text(
                _confirmed
                    ? 'Confirmed · Waiting for Everyone'
                    : 'Confirm & Approve Schedule',
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => _act('reject'),
              child: const Text('Request Changes & Return to Draft'),
            ),
          ],
          if (_draft && _owner) ...[
            OutlinedButton(
              onPressed: _busy ? null : _importRoutine,
              child: const Text('Import reusable routine'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _act('generate-schedule'),
              child: const Text('Generate / regenerate draft'),
            ),
            FilledButton(
              onPressed: _busy || (_summary['unassignedCount'] ?? 1) > 0
                  ? null
                  : () => _act('submit-review'),
              child: const Text('Submit for everyone to review'),
            ),
          ],
          const SizedBox(height: 12),
          _panel(
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _draft,
              title: Text(
                'Assignment Details (${_occurrences.length})',
                style: const TextStyle(fontSize: 13),
              ),
              children: [
                for (final item in _occurrences)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item['choreName'] ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${item['assignedUserDisplayName'] ?? 'Unassigned'} · ${item['dueDate']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: _draft && _owner
                        ? TextButton(
                            onPressed: _busy
                                ? null
                                : () =>
                                      _assign(Map<String, dynamic>.from(item)),
                            child: const Text('Assign'),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
