import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../../ai/data/ai_repository.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../providers/action_proposal_providers.dart';
import 'assistant_requests.dart';

class AiUrgentPlanCard extends ConsumerStatefulWidget {
  const AiUrgentPlanCard({
    required this.houseId,
    required this.prompt,
    required this.candidate,
    super.key,
  });
  final String houseId;
  final String prompt;
  final Map<String, dynamic> candidate;

  @override
  ConsumerState<AiUrgentPlanCard> createState() => _AiUrgentPlanCardState();
}

class _AiUrgentPlanCardState extends ConsumerState<AiUrgentPlanCard> {
  String _taskTimes(Map task) {
    final start = DateTime.tryParse(task['start_at']?.toString() ?? '');
    final end = DateTime.tryParse(task['end_at']?.toString() ?? '');
    if (start == null || end == null) return '';
    return '\n${DateFormat.Hm().format(start.toLocal())}–${DateFormat.Hm().format(end.toLocal())}';
  }

  Map<String, dynamic>? _plan;
  final _requestId = const Uuid().v4();
  bool _busy = true;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_generate);
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final season = await ref.read(
        activeSeasonProvider(widget.houseId).future,
      );
      if (!mounted) return;
      if (season == null) {
        setState(
          () => _error = 'An active season is required to plan urgent tasks.',
        );
        return;
      }
      final result = await ref.read(aiRepositoryProvider).post(
        widget.houseId,
        'urgent/request',
        {
          'clientRequestId': _requestId,
          'seasonId': season['id'],
          'text': widget.prompt,
          if (widget.candidate['deadline_minutes'] != null)
            'deadlineMinutes': widget.candidate['deadline_minutes'],
          if (widget.candidate['ready_by'] != null)
            'readyBy': widget.candidate['ready_by'],
          if (widget.candidate['guest_count'] != null)
            'guestCount': widget.candidate['guest_count'],
          'participantIds': widget.candidate['participant_ids'],
          'resources': widget.candidate['resources'] ?? [],
        },
      );
      if (!mounted) return;
      setState(() => _plan = result);
      if (result['proposal_id'] != null) {
        setState(() => _sent = true);
        _refreshRequests();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = apiErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshRequests() {
    final room = ref
        .read(assistantRequestRoomProvider(widget.houseId))
        .asData
        ?.value;
    if (room != null) {
      ref.read(actionProposalProvider(room).notifier).loadProposals();
    }
    ref.invalidate(activeUrgentEventForHouseProvider(widget.houseId));
  }

  @override
  Widget build(BuildContext context) {
    final result = _plan?['result'] as Map?;
    final members =
        ref.watch(houseMembersProvider(widget.houseId)).asData?.value ?? [];
    final names = {
      for (final member in members) member.userId: member.displayName,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result?['title']?.toString() ?? 'Urgent task plan',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (widget.candidate['guest_count'] != null)
              Text('${widget.candidate['guest_count']} guests'),
            if (widget.candidate['ready_by'] is String)
              Text(
                'Ready by ${DateFormat.MMMd('en_US').add_Hm().format(DateTime.parse(widget.candidate['ready_by'] as String).toLocal())}',
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            for (final task in result?['tasks'] as List? ?? [])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${task['name']} · ${names[task['assigned_to']] ?? 'Household member'} · ${task['minutes']} min${_taskTimes(task as Map)}',
                ),
              ),
            if (result != null && result['status'] != 'READY')
              Text(
                result['status'] == 'NEEDS_CLARIFICATION'
                    ? 'Please clarify: ${(result['missing_fields'] as List? ?? []).join(', ')}'
                    : 'This plan does not fit the current availability or time budget. Please adjust your request.',
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_sent)
              const Text(
                'Requests sent. Participants can review them in Assistant or Household Chat. The campaign starts after everyone approves.',
              ),
            if (!_sent && result?['status'] == 'READY') ...[
              const Text(
                'Each participant must approve before the campaign starts.',
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _generate,
                child: const Text('Retry sending requests'),
              ),
            ],
            if (_error != null && !_busy && _plan == null)
              TextButton(onPressed: _generate, child: const Text('Retry plan')),
          ],
        ),
      ),
    );
  }
}
