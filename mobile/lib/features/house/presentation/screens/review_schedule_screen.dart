import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../chore/presentation/providers/chore_providers.dart';
import '../../../../core/widgets/member_avatar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';
import '../providers/house_providers.dart';
import '../widgets/household_summary_sections.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/house_models.dart';

class ReviewScheduleScreen extends ConsumerStatefulWidget {
  const ReviewScheduleScreen({
    required this.houseId,
    required this.seasonId,
    super.key,
  });
  final String houseId, seasonId;
  @override
  ConsumerState<ReviewScheduleScreen> createState() =>
      _ReviewScheduleScreenState();
}

class _ReviewScheduleScreenState extends ConsumerState<ReviewScheduleScreen> {
  Map<String, dynamic>? _season;
  List<dynamic> _occurrences = [];
  bool _busy = false;
  bool _reloadPending = false;
  String? _error;
  String get _base => '/houses/${widget.houseId}/seasons/${widget.seasonId}';
  bool get _draft => _season?['status'] == 0 || _season?['status'] == 'DRAFT';
  bool get _reviewing =>
      _season?['status'] == 1 || _season?['status'] == 'REVIEWING';
  bool get _active => _season?['status'] == 2 || _season?['status'] == 'ACTIVE';
  bool get _owner =>
      ref.watch(houseDetailProvider(widget.houseId)).asData?.value.myRole ==
      HouseRole.owner;
  List<dynamic> get _confirmations => (_season?['confirmations'] as List? ?? [])
      .where(
        (c) =>
            c['scheduleRevision'] == null ||
            c['scheduleRevision'] == _season?['scheduleRevision'],
      )
      .toList();
  bool _rejected(String user) => _confirmations.any(
    (c) =>
        c['userId'] == user && (c['status'] == 2 || c['status'] == 'REJECTED'),
  );
  bool _signed(String user) => _confirmations.any(
    (c) =>
        c['userId'] == user && (c['status'] == 1 || c['status'] == 'CONFIRMED'),
  );
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
      // Approval remains usable even when an unrelated summary request fails.
      final response = await dio.get('/houses/${widget.houseId}/seasons');
      if (!mounted) return;
      setState(
        () => _season = Map<String, dynamic>.from(
          (response.data as List).firstWhere((s) => s['id'] == widget.seasonId),
        ),
      );
      final occurrences = await dio.get('$_base/occurrences');
      if (mounted) setState(() => _occurrences = List.from(occurrences.data));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_reloadPending) {
          _reloadPending = false;
          Future.microtask(() {
            if (mounted) _load();
          });
        }
      }
    }
  }

  Future<void> _act(String action) async {
    if (_busy) return;
    String? reason;
    if (action == 'reject') {
      final input = TextEditingController();
      try {
        reason = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Request schedule changes'),
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
                child: const Text('Request changes'),
              ),
            ],
          ),
        );
      } finally {
        input.dispose();
      }
      if (reason == null || reason.isEmpty) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
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
      refreshChoreState(ref, widget.houseId);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
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
        title: const Text('Assign chore'),
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
      if (mounted) {
        refreshHouseState(ref, houseId: widget.houseId);
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redistribute(String target) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '$_base/redistribution-preview',
        queryParameters: {'targetUserId': target},
      );
      final plan = Map<String, dynamic>.from(response.data);
      final changes = plan['changes'] as List? ?? [];
      final requestId = const Uuid().v4();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Review redistribution'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${changes.length} chores will move. Existing deadlines and time slots stay unchanged.',
                  ),
                  for (final change in changes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(change['choreName']),
                      subtitle: Text(
                        'Due ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(change['dueAt']).toUtc().add(const Duration(hours: 7)))} (Vietnam)',
                      ),
                    ),
                  for (final reason in plan['reasons'] as List? ?? [])
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(reason.toString()),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            if (changes.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm redistribution'),
              ),
          ],
        ),
      );
      if (confirmed != true) return;
      await dio.post(
        '$_base/redistribute',
        data: {
          'targetUserId': target,
          'expectedRevision': plan['baseRevision'],
          'contextHash': plan['contextHash'],
          'clientRequestId': requestId,
        },
      );
      if (mounted) {
        refreshHouseState(ref, houseId: widget.houseId);
        refreshChoreState(ref, widget.houseId);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Schedule updated.')));
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationNotifierProvider.select((s) => s.latestArrival), (
      previous,
      next,
    ) {
      if (next != null && next.houseId == widget.houseId && !next.isChat) {
        if (_busy) {
          _reloadPending = true;
        } else {
          _load();
        }
      }
    });
    final members =
        ref
            .watch(houseMembersProvider(widget.houseId))
            .asData
            ?.value
            .where((m) => m.isActive)
            .toList() ??
        <HouseMember>[];
    final me = ref.watch(userProfileProvider).asData?.value.id;
    final waiting = members.where((m) => !_signed(m.userId)).toList();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => context.go('/houses/${widget.houseId}'),
          ),
          title: const Text(
            'Household Summary',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh schedule',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
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
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (_season != null) ...[
                  Text(
                    '${_season!['name']} · Revision ${_season!['scheduleRevision']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _reviewing
                        ? '${members.length - waiting.length}/${members.length} approvals. Waiting for ${waiting.map((m) => m.displayName).join(', ')}.'
                        : _active
                        ? 'The season is active. New members receive eligible future chores automatically.'
                        : 'Prepare the schedule, then submit it for everyone to review.',
                  ),
                  const SizedBox(height: 16),
                  if (_reviewing)
                    FilledButton.icon(
                      onPressed: _busy || me == null || _signed(me)
                          ? null
                          : () => _act('confirm'),
                      icon: const Icon(Icons.done_all),
                      label: Text(
                        me != null && _signed(me)
                            ? 'Confirmed · Waiting for other members'
                            : 'Confirm & Approve Schedule',
                      ),
                    ),
                  if (_reviewing)
                    TextButton(
                      onPressed: _busy ? null : () => _act('reject'),
                      child: const Text('Request changes'),
                    ),
                  for (final member in members)
                    Card(
                      child: ListTile(
                        leading: MemberAvatar(
                          houseId: widget.houseId,
                          userId: member.userId,
                          name: member.displayName,
                          version: member.avatarUrl ?? '',
                        ),
                        title: Text(member.displayName),
                        subtitle: Text(
                          _reviewing
                              ? _signed(member.userId)
                                    ? 'Confirmed'
                                    : _rejected(member.userId)
                                    ? 'Rejected'
                                    : 'Awaiting confirmation'
                              : member.isOwner
                              ? 'Owner'
                              : 'Member',
                        ),
                        trailing: _owner && (_draft || _reviewing || _active)
                            ? IconButton(
                                tooltip:
                                    'Review redistribution for ${member.displayName}',
                                onPressed: _busy
                                    ? null
                                    : () => _redistribute(member.userId),
                                icon: const Icon(Icons.swap_horiz),
                              )
                            : null,
                      ),
                    ),
                  if (_draft && _owner) ...[
                    OutlinedButton(
                      onPressed: _busy ? null : () => _act('generate-schedule'),
                      child: const Text('Generate / regenerate draft'),
                    ),
                    FilledButton(
                      onPressed:
                          _busy ||
                              _occurrences.isEmpty ||
                              _occurrences.any(
                                (o) =>
                                    (o['type'] == 0 || o['type'] == 'NORMAL') &&
                                    o['assignedUserId'] == null,
                              )
                          ? null
                          : () => _act('submit-review'),
                      child: const Text('Submit for everyone to review'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_owner && (_draft || _active)) ...[
                    for (final occurrence in _occurrences.where(
                      (o) =>
                          (o['type'] == 0 || o['type'] == 'NORMAL') &&
                          o['assignedUserId'] == null,
                    ))
                      ListTile(
                        title: Text(occurrence['choreName']),
                        subtitle: const Text(
                          'Needs assignment · Review member availability',
                        ),
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _assign(
                                  Map<String, dynamic>.from(occurrence),
                                ),
                          child: const Text('Assign'),
                        ),
                      ),
                  ],
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.go('/houses/${widget.houseId}/chores?tab=team'),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('View team schedule'),
                  ),
                  TextButton(
                    onPressed: () => context.push(
                      '/houses/${widget.houseId}/seasons/${widget.seasonId}/leaderboard',
                    ),
                    child: const Text('Season ranking'),
                  ),
                ],
              ],
            ),
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
  }
}
