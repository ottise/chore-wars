import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Review schedule'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_season?['lastRejectionReason'] != null)
          Text('Last rejection: ${_season!['lastRejectionReason']}'),
        Text('Revision ${_season?['scheduleRevision'] ?? 0}'),
        const Text(
          'All active members must approve the same schedule before the season starts.',
        ),
        for (final member in (_summary['members'] as List? ?? []))
          ListTile(
            title: Text(member['displayName'] ?? ''),
            subtitle: Text(
              '${member['totalAssignedKarma'] ?? 0} Karma · ${member['totalEstimatedMinutes'] ?? 0} min',
            ),
          ),
        for (final warning in (_summary['warnings'] as List? ?? []))
          Text(
            warning.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final c in (_season?['confirmations'] as List? ?? []))
          ListTile(
            title: Text(c['userId'].toString()),
            subtitle: Text('Confirmation: ${c['status']}'),
          ),
        for (final item in _occurrences)
          Card(
            child: ListTile(
              title: Text(item['choreName'] ?? ''),
              subtitle: Text(
                '${item['assignedUserDisplayName'] ?? 'Unassigned'} · ${item['dueDate']}',
              ),
              trailing: _draft && _owner
                  ? TextButton(
                      onPressed: _busy
                          ? null
                          : () => _assign(Map<String, dynamic>.from(item)),
                      child: const Text('Assign'),
                    )
                  : null,
            ),
          ),
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
        if (_reviewing) ...[
          FilledButton(
            onPressed: _busy || _confirmed ? null : () => _act('confirm'),
            child: Text(
              _confirmed
                  ? 'Confirmed — waiting for other members'
                  : 'Confirm this revision',
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _act('reject'),
            child: const Text('Reject and return to draft'),
          ),
        ],
      ],
    ),
  );
}
