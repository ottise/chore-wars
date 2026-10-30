import 'package:intl/intl.dart';

import '../../../core/utils/vietnam_time.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_provider.dart';
import '../../../core/utils/api_error_message.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../house/presentation/providers/house_providers.dart';
import '../data/ai_repository.dart';

class AiPlanningScreen extends ConsumerStatefulWidget {
  const AiPlanningScreen({
    super.key,
    required this.houseId,
    required this.kind,
    this.sourceOccurrenceId,
    this.initialRecord,
  });
  final String houseId, kind;
  final String? sourceOccurrenceId;
  final Map<String, dynamic>? initialRecord;
  @override
  ConsumerState<AiPlanningScreen> createState() => _AiPlanningScreenState();
}

class _AiPlanningScreenState extends ConsumerState<AiPlanningScreen> {
  final text = TextEditingController(),
      resources = TextEditingController(),
      budget = TextEditingController(text: '60');
  List<Map<String, dynamic>> seasons = [];
  Map<String, dynamic>? record;
  String? season, previous, error, sourceOccurrence;
  final participants = <String>{};
  String request = const Uuid().v4();
  bool busy = false;
  int? epoch;
  bool get active => mounted && ref.read(sessionEpochProvider) == epoch;
  @override
  void initState() {
    super.initState();
    record = widget.initialRecord;
    sourceOccurrence = widget.sourceOccurrenceId;
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    text.dispose();
    resources.dispose();
    budget.dispose();
    super.dispose();
  }

  Future<void> operation(Future<void> Function() body) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await body();
    } catch (e) {
      if (active) setState(() => error = apiErrorMessage(e));
    } finally {
      if (active) setState(() => busy = false);
    }
  }

  Future<void> load() => operation(() async {
    final response = await ref
        .read(dioProvider)
        .get('/houses/${widget.houseId}/seasons');
    if (!active) return;
    setState(
      () => seasons = (response.data as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList(),
    );
    final desired = widget.kind == 'EVOLUTION' ? 'DRAFT' : 'ACTIVE';
    final wanted = seasons
        .where(
          (s) =>
              s['status'] == desired ||
              s['status'] == (desired == 'DRAFT' ? 0 : 2),
        )
        .toList();
    if (wanted.isNotEmpty) {
      setState(() => season = wanted.first['id'].toString());
    }
  });
  @override
  Widget build(BuildContext context) {
    final current = ref.watch(sessionEpochProvider);
    epoch ??= current;
    if (epoch != current) {
      return const Scaffold(
        body: Center(child: Text('Your session changed. Reopen the request.')),
      );
    }
    final members =
        ref.watch(houseMembersProvider(widget.houseId)).asData?.value ?? [];
    final actor = ref.watch(userProfileProvider).asData?.value.id;
    final names = {
      for (final member in members) member.userId: member.displayName,
    };
    final result = record?['result'] as Map?;
    final frozen = busy || record != null;
    final isUrgent = widget.kind == 'URGENT';
    final swapOptions = widget.kind == 'SWAP' && season != null
        ? ref.watch(
            aiSwapOccurrencesProvider((house: widget.houseId, season: season!)),
          )
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);
    final eligible = (swapOptions.asData?.value ?? [])
        .where(
          (c) =>
              actor != null &&
              c['assignedUserId'] == actor &&
              (c['type'] == 0 || c['type'] == 'NORMAL') &&
              (c['status'] == 0 || c['status'] == 'ASSIGNED') &&
              (DateTime.tryParse(c['dueDate'].toString())
                      ?.isAfter(DateTime.now()) ??
                  false),
        )
        .toList();
    final validSource = eligible.any((c) => c['id'] == sourceOccurrence);
    final title = switch (widget.kind) {
      'SWAP' => 'Find a Chore Swap',
      'REPLAN' => 'Replan Future Chores',
      'EVOLUTION' => 'Next Season Schedule',
      _ => 'Urgent Campaign',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Preview before sending. Changes to active schedules require approval from affected members; draft schedules still require season review.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: season,
            decoration: const InputDecoration(labelText: 'Working Season'),
            items: [
              for (final s in seasons.where(
                (s) => widget.kind == 'EVOLUTION'
                    ? (s['status'] == 0 || s['status'] == 'DRAFT')
                    : (s['status'] == 2 || s['status'] == 'ACTIVE'),
              ))
                DropdownMenuItem(
                  value: s['id'].toString(),
                  child: Text(s['name']?.toString() ?? s['id'].toString()),
                ),
            ],
            onChanged: frozen
                ? null
                : (value) => setState(() => season = value),
          ),
          if (widget.kind == 'EVOLUTION')
            DropdownButtonFormField<String>(
              initialValue: previous,
              decoration: const InputDecoration(
                labelText: 'Completed Reference Season',
              ),
              items: [
                for (final s in seasons.where(
                  (s) => s['status'] == 3 || s['status'] == 'COMPLETED',
                ))
                  DropdownMenuItem(
                    value: s['id'].toString(),
                    child: Text(s['name']?.toString() ?? s['id'].toString()),
                  ),
              ],
              onChanged: frozen
                  ? null
                  : (value) => setState(() => previous = value),
            ),
          if (widget.kind == 'SWAP') ...[
            const Text(
              'Only eligible swaps are suggested. Both members review before responsibility changes.',
            ),
            if (swapOptions.isLoading) const LinearProgressIndicator(),
            if (swapOptions.hasError)
              TextButton(
                onPressed: () => ref.invalidate(
                  aiSwapOccurrencesProvider((
                    house: widget.houseId,
                    season: season!,
                  )),
                ),
                child: const Text('Retry eligible chores'),
              ),
            DropdownButtonFormField<String>(
              key: ValueKey((season, validSource ? sourceOccurrence : null)),
              initialValue: validSource ? sourceOccurrence : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Your chore to swap',
              ),
              items: [
                for (final c in eligible)
                  DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(
                      "${c['choreName']} · ${DateFormat('dd/MM HH:mm').format(vietnamTime(c['dueDate']))}",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: frozen
                  ? null
                  : (id) => setState(() => sourceOccurrence = id),
            ),
          ],
          if (isUrgent) ...[
            TextField(
              controller: text,
              enabled: !frozen,
              maxLines: 4,
              maxLength: 8000,
              decoration: const InputDecoration(
                labelText: 'What needs to be done?',
              ),
            ),
            TextField(
              controller: budget,
              enabled: !frozen,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Time Budget (minutes)',
              ),
            ),
            TextField(
              controller: resources,
              enabled: !frozen,
              decoration: const InputDecoration(
                labelText: 'Available Resources, Separated by Commas',
                hintText: 'vacuum cleaner, sink',
              ),
            ),
            const Text('Participants (including you):'),
            for (final member in members)
              CheckboxListTile(
                value:
                    member.userId == actor ||
                    participants.contains(member.userId),
                title: Text(member.displayName),
                onChanged: frozen || member.userId == actor
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          participants.add(member.userId);
                        } else {
                          participants.remove(member.userId);
                        }
                      }),
              ),
          ],
          if (record == null)
            FilledButton.icon(
              onPressed:
                  busy ||
                      season == null ||
                      (widget.kind == 'SWAP' && !validSource)
                  ? null
                  : () => operation(() async {
                      if (widget.kind == 'EVOLUTION' && previous == null) {
                        throw StateError('Choose a reference season first.');
                      }
                      final path = switch (widget.kind) {
                        'SWAP' => 'schedules/swap',
                        'REPLAN' => 'schedules/replan',
                        'EVOLUTION' => 'seasons/evolve',
                        _ => 'urgent/plan',
                      };
                      final response = await ref
                          .read(aiRepositoryProvider)
                          .post(widget.houseId, path, {
                            'clientRequestId': request,
                            'seasonId': season,
                            'sourceOccurrenceId': sourceOccurrence,
                            'sourceSeasonId': previous,
                            if (isUrgent) ...{
                              'text': text.text,
                              'deadlineMinutes': int.tryParse(budget.text) ?? 0,
                              'participantIds': {
                                ...participants,
                                ?actor,
                              }.toList(),
                              'resources': resources.text
                                  .split(',')
                                  .map((s) => s.trim())
                                  .where((s) => s.isNotEmpty)
                                  .toSet()
                                  .toList(),
                            },
                          });
                      if (active) setState(() => record = response);
                    }),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Create Preview'),
            ),
          if (record != null) ...[
            const Divider(height: 32),
            Text('Status: ${record!['status']}'),
            for (final change in record!['availability_changes'] as List? ?? [])
              Text(
                'Proposed availability: ${change['LocalDate'] ?? change['localDate']} · ${change['Slots'] ?? change['slots']}',
              ),
            if (result?['reason'] != null) Text(result!['reason'].toString()),
            if (result?['status'] != null) Text(result!['status'].toString()),
            for (final field in result?['missing_fields'] as List? ?? [])
              Text('Needs clarification: $field'),
            for (final task in result?['tasks'] as List? ?? [])
              ListTile(
                title: Text(task['name']?.toString() ?? 'Chore'),
                subtitle: Text(
                  '${names[task['assigned_to']] ?? 'Unassigned'} · ${task['start_at'] ?? 'Time not assigned'}${task['end_at'] == null ? '' : ' → ${task['end_at']}'}\n${(task['dependencies'] as List? ?? []).isEmpty ? '' : 'Dependencies: ${task['dependencies']}'}',
                ),
              ),
            for (final key in result?['unplaced'] as List? ?? [])
              Text('Could not schedule: $key'),
            if (record!['status'] == 'READY' &&
                result?['status'] != 'INFEASIBLE' &&
                result?['status'] != 'NEEDS_CLARIFICATION')
              FilledButton(
                onPressed: busy
                    ? null
                    : () => operation(() async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Send Reviewed Proposal?'),
                            content: const Text(
                              'The system will recheck the current schedule and request approval from affected members. If the data has changed, review a new proposal.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Send Proposal'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !active) return;
                        final response = await ref
                            .read(aiRepositoryProvider)
                            .post(
                              widget.houseId,
                              'recommendations/${record!['id']}/accept',
                              {},
                            );
                        if (active) setState(() => record = response);
                        ref.invalidate(activeSeasonProvider(widget.houseId));
                      }),
                child: const Text('Send Reviewed Proposal'),
              ),
            if (record!['proposal_id'] != null)
              const Text(
                'Requests were sent to the private AI conversations of affected members. Changes apply only after everyone confirms.',
              ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      record = null;
                      request = const Uuid().v4();
                    }),
              child: const Text('Create Another Request'),
            ),
          ],
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
