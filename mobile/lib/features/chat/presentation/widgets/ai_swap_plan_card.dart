import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../ai/data/ai_repository.dart';
import '../../../chat/providers/action_proposal_providers.dart';
import '../../../house/presentation/providers/house_providers.dart';

class AiSwapPlanCard extends ConsumerStatefulWidget {
  const AiSwapPlanCard({
    required this.houseId,
    required this.prompt,
    required this.clientRequestId,
    this.sourceOccurrenceId,
    this.targetMemberId,
    super.key,
  });

  final String houseId;
  final String prompt;
  final String clientRequestId;
  final String? sourceOccurrenceId;
  final String? targetMemberId;

  @override
  ConsumerState<AiSwapPlanCard> createState() => _AiSwapPlanCardState();
}

class _AiSwapPlanCardState extends ConsumerState<AiSwapPlanCard> {
  late String _requestId;
  String? _recommendationId;
  Map<String, dynamic>? _plan;
  bool _busy = true;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestId = widget.clientRequestId;
    Future.microtask(_planAndSend);
  }

  Future<void> _planAndSend() async {
    if (!mounted || _busy && _plan != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_recommendationId != null && _plan?['accepted'] == true) {
        await _acceptAndSend(_recommendationId!);
        return;
      }
      final season = await ref.read(
        activeSeasonProvider(widget.houseId).future,
      );
      if (!mounted) return;
      if (season == null) {
        throw StateError('An active season is required to swap chores.');
      }

      final repository = ref.read(aiRepositoryProvider);
      final recommendation = await repository.post(
        widget.houseId,
        'schedules/swap',
        {
          'clientRequestId': _requestId,
          'seasonId': season['id'],
          'text': widget.prompt,
          if (widget.sourceOccurrenceId != null)
            'sourceOccurrenceId': widget.sourceOccurrenceId,
          if (widget.targetMemberId != null)
            'targetMemberId': widget.targetMemberId,
        },
      );
      if (!mounted) return;

      final plan = recommendation['result'] is Map
          ? Map<String, dynamic>.from(recommendation['result'] as Map)
          : <String, dynamic>{};
      _recommendationId = recommendation['id']?.toString();
      setState(() => _plan = plan);
      if (recommendation['proposal_id'] != null) {
        setState(() => _sent = true);
        _refreshRequests();
        return;
      }
      if (recommendation['status'] != 'READY' ||
          plan['accepted'] != true ||
          plan['swap_payload'] is! Map) {
        setState(() {
          _error = 'I could not find a feasible swap in the current schedule.';
        });
        return;
      }

      await _acceptAndSend(_recommendationId!);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptAndSend(String recommendationId) async {
    final accepted = await ref.read(aiRepositoryProvider).post(
      widget.houseId,
      'recommendations/$recommendationId/accept',
      const {},
    );
    if (!mounted) return;
    if (accepted['proposal_id'] == null) {
      throw StateError('The swap request was not sent. Please try again.');
    }
    setState(() => _sent = true);
    _refreshRequests();
  }

  void _refreshRequests() {
    final room = ref
        .read(assistantRequestRoomProvider(widget.houseId))
        .asData
        ?.value;
    if (room != null) {
      ref.read(actionProposalProvider(room).notifier).loadProposals();
    }
    ref.invalidate(assistantInboxProvider(widget.houseId));
  }

  @override
  Widget build(BuildContext context) {
    final members =
        ref.watch(houseMembersProvider(widget.houseId)).asData?.value ?? [];
    final names = {
      for (final member in members) member.userId: member.displayName,
    };
    final payload = _plan?['swap_payload'] as Map?;
    final changedIds = {
      payload?['SourceOccurrenceId']?.toString() ??
          payload?['sourceOccurrenceId']?.toString(),
      payload?['TargetOccurrenceId']?.toString() ??
          payload?['targetOccurrenceId']?.toString(),
    };
    final changedTasks = (_plan?['tasks'] as List? ?? [])
        .whereType<Map>()
        .map((task) => Map<String, dynamic>.from(task))
        .where((task) => changedIds.contains(task['id']?.toString()))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI chore swap',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text(
                'Finding a compatible chore and sending it for approval…',
              ),
            ],
            for (final task in changedTasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(task['name']?.toString() ?? 'Chore'),
                subtitle: Text(
                  '${names[task['assigned_to']?.toString()] ?? 'Household member'} · ${_time(task['start_at'])}',
                ),
              ),
            if (_sent)
              const Text(
                'Swap request sent to the other member. The schedule changes after they confirm in their AI conversation.',
              ),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (!_busy)
                TextButton(
                  onPressed: () {
                    if (_plan?['accepted'] != true) {
                      _requestId = const Uuid().v4();
                      _recommendationId = null;
                    }
                    _planAndSend();
                  },
                  child: const Text('Try another swap'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _time(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? 'Time not assigned'
        : DateFormat('dd/MM HH:mm').format(parsed.toLocal());
  }
}
