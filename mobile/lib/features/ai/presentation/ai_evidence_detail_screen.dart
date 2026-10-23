import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_states.dart';
import '../data/ai_repository.dart';

class AiEvidenceDetailScreen extends ConsumerWidget {
  const AiEvidenceDetailScreen({
    super.key,
    required this.houseId,
    required this.evidenceId,
  });
  final String houseId, evidenceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (house: houseId, path: 'evidence/$evidenceId');
    return Scaffold(
      appBar: AppBar(title: const Text('Contribution Evidence')),
      body: ref
          .watch(aiDataProvider(query))
          .when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(aiDataProvider(query)),
            ),
            data: (data) {
              final payload = data['payload'] as Map;
              final occurrence = data['event_type'] == 'occurrence.upsert'
                  ? data['entity_id']
                  : payload['occurrence_id'];
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (data['data_source'] == 'DEMO_SYNTHETIC')
                    const Chip(label: Text('Synthetic Evidence')),
                  Text(switch (data['event_type']) {
                    'occurrence.upsert' => 'Chore Outcome',
                    'episode.upsert' => 'Responsibility History',
                    'ledger.upsert' => 'Karma Transaction',
                    'ranking.upsert' => 'Season Ranking Result',
                    'bounty.upsert' => 'Bounty Posting History',
                    'proposal.upsert' => 'Adjustment Request',
                    'payment.upsert' => 'Payment Confirmation',
                    _ => 'Activity Evidence',
                  }, style: Theme.of(context).textTheme.headlineSmall),
                  Text('Recorded at ${data['recorded_at']}'),
                  for (final entry in payload.entries)
                    ListTile(
                      title: Text(
                        {
                              'name': 'Chore',
                              'minutes': 'Standard Effort (minutes)',
                              'karma': 'Chore Karma',
                              'completed_at': 'Completed at',
                              'completed_by': 'Actual Completer',
                              'reason': 'Responsibility Source',
                              'started_at': 'Responsibility Started at',
                              'ended_at': 'Responsibility Ended at',
                              'amount': data['event_type'] == 'ledger.upsert'
                                  ? 'Karma Amount'
                                  : 'Amount (VND)',
                              'type': 'Transaction Type',
                              'rank': 'Rank',
                              'member_count': 'Ranked Member Count',
                              'total_karma': 'Season Karma',
                              'chores_completed': 'Completed Chore Count',
                            }[entry.key] ??
                            entry.key.toString(),
                      ),
                      subtitle: SelectableText(
                        entry.value?.toString() ?? 'Unknown',
                      ),
                    ),
                  if (occurrence != null)
                    TextButton(
                      onPressed: () =>
                          context.push('/houses/$houseId/chores/$occurrence'),
                      child: const Text('Open Original Chore'),
                    ),
                  ExpansionTile(
                    title: const Text('Trace Details'),
                    children: [
                      SelectableText(
                        'Event: $evidenceId\nSource sequence: ${data['house_sequence']}',
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
    );
  }
}
