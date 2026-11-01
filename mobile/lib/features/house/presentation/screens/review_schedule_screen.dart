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
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9FE),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF9FE),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go('/houses/${widget.houseId}');
              }
            },
          ),
          title: const Text(
            'House Pulse',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh schedule',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF7C4DFF),
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: Color(0xFF7C4DFF),
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Spending & Payments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            HouseholdSummarySection(
              houseId: widget.houseId,
              seasonId: widget.seasonId,
              section: 2,
              seasonName: _season?['name']?.toString(),
              occurrences: _occurrences,
              scheduleHeader: !_active
                  ? _buildScheduleSection(
                      context,
                      members: members,
                      waiting: waiting,
                      me: me,
                    )
                  : null,
            ),
            HouseholdSummarySection(
              houseId: widget.houseId,
              seasonId: widget.seasonId,
              section: 1,
              seasonName: _season?['name']?.toString(),
              occurrences: _occurrences,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection(
    BuildContext context, {
    required List<HouseMember> members,
    required List<HouseMember> waiting,
    required String? me,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDEAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _reviewing
                  ? '${members.length - waiting.length}/${members.length} approvals. Waiting for ${waiting.map((m) => m.displayName).join(', ')}.'
                  : _active
                  ? 'The season is active. New members receive eligible future chores automatically.'
                  : 'Prepare the schedule, then submit it for everyone to review.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            if (_reviewing) ...[
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
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _busy ? null : () => _act('reject'),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Request changes'),
                    ),
                  ),
                  if (_owner)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _busy ? null : () => _act('reset-draft'),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('Về bản nháp'),
                      ),
                    ),
                ],
              ),
            ],
            for (final member in members)
              Card(
                elevation: 0,
                color: const Color(0xFFF8FAFC),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFEDEAF6)),
                ),
                child: ListTile(
                  leading: MemberAvatar(
                    houseId: widget.houseId,
                    userId: member.userId,
                    name: member.displayName,
                    version: member.avatarUrl ?? '',
                  ),
                  title: Text(
                    member.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
              _buildWorkflowCard(
                context,
                hasOccurrences: _occurrences.any((o) => o['type'] == 0 || o['type'] == 'NORMAL'),
                mandatoryCount: _occurrences.where((o) => o['type'] == 0 || o['type'] == 'NORMAL').length,
                unassignedCount: _occurrences.where((o) => (o['type'] == 0 || o['type'] == 'NORMAL') && o['assignedUserId'] == null).length,
                allAssigned: _occurrences.isNotEmpty && !_occurrences.any((o) => (o['type'] == 0 || o['type'] == 'NORMAL') && o['assignedUserId'] == null),
              ),
            ],
            const SizedBox(height: 12),
            if (_owner && (_draft || _active)) ...[
              for (final occurrence in _occurrences.where(
                (o) =>
                    (o['type'] == 0 || o['type'] == 'NORMAL') &&
                    o['assignedUserId'] == null,
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
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
            TextButton(
              onPressed: () => context.push(
                '/houses/${widget.houseId}/seasons/${widget.seasonId}/leaderboard',
              ),
              child: const Text('Season ranking'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkflowCard(
    BuildContext context, {
    required bool hasOccurrences,
    required int mandatoryCount,
    required int unassignedCount,
    required bool allAssigned,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D7FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: Color(0xFF7C4DFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quy trình chuẩn bị lịch mùa',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '3 bước trước khi chốt lịch',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStepRow(
            stepNumber: '1',
            title: 'Sinh lịch việc cho từng ngày',
            status: hasOccurrences
                ? 'Đã sinh $mandatoryCount việc nhà'
                : 'Chưa sinh lịch các ngày',
            isDone: hasOccurrences,
            action: OutlinedButton.icon(
              onPressed: _busy ? null : () => _act('generate-schedule?autoAllocate=false'),
              icon: const Icon(Icons.calendar_month, size: 16),
              label: Text(hasOccurrences ? 'Sinh lại lịch việc' : '1. Sinh lịch việc'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const Divider(height: 24, color: Color(0xFFEDEAF6)),
          _buildStepRow(
            stepNumber: '2',
            title: 'AI tự động phân công việc',
            status: !hasOccurrences
                ? 'Cần hoàn thành Bước 1 trước'
                : allAssigned
                    ? '100% đã được gán ($mandatoryCount việc)'
                    : 'Còn $unassignedCount việc chưa phân công',
            isDone: allAssigned,
            action: FilledButton.tonalIcon(
              onPressed: _busy || !hasOccurrences ? null : () => _act('auto-assign'),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(allAssigned ? 'AI phân công lại' : '2. AI phân công việc'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const Divider(height: 24, color: Color(0xFFEDEAF6)),
          _buildStepRow(
            stepNumber: '3',
            title: 'Chốt lịch & Gửi mọi người duyệt',
            status: !hasOccurrences
                ? 'Chưa có lịch để gửi'
                : !allAssigned
                    ? 'Cần phân công hết việc trước khi chốt'
                    : 'Sẵn sàng gửi để mọi người cùng duyệt',
            isDone: false,
            action: FilledButton.icon(
              onPressed: _busy || !allAssigned ? null : () => _act('submit-review'),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('3. Chốt lịch & Gửi duyệt'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: const Color(0xFF7C4DFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String stepNumber,
    required String title,
    required String status,
    required bool isDone,
    required Widget action,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFF10B981) : const Color(0xFF7C4DFF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        stepNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 30, top: 4, bottom: 8),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: isDone ? const Color(0xFF059669) : const Color(0xFF64748B),
              fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: action,
        ),
      ],
    );
  }
}
