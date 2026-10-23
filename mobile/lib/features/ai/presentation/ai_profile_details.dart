import 'package:flutter/material.dart';

import 'ai_evidence_detail_screen.dart';

class AiProfileDetails extends StatelessWidget {
  const AiProfileDetails({
    super.key,
    required this.houseId,
    required this.profile,
  });

  final String houseId;
  final Map<String, dynamic> profile;

  static const _labels = {
    'completed_count': 'Completed Chores',
    'standard_minutes': 'Standard Workload',
    'snapshot_karma': 'Karma from Completed Chores',
    'responsibility_count': 'Responsibility Episodes',
    'on_time_episode_rate': 'On-Time Completion',
    'bounty_claim_count': 'Bounty Acceptances',
    'bounty_occurrence_count': 'Distinct Bounty Chores Accepted',
    'bounty_self_completion_rate': 'Self-Completed Bounty Chores',
    'bounty_posted_count': 'Bounties Posted',
    'mean_normalized_rank': 'Mean Normalized Rank',
  };

  String _value(Map metric) {
    final value = metric['value'];
    if (value == null) return 'Insufficient Samples';
    if (metric['unit'] == 'ratio' && value is num) {
      return '${(value * 100).toStringAsFixed(1)}%';
    }
    return '$value${metric['unit'] == 'standard_minutes' ? ' standard minutes' : ''}';
  }

  List<Widget> _evidence(BuildContext context, List ids) => [
    for (final id in ids.take(20))
      ListTile(
        dense: true,
        title: const Text('View Metric Evidence'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AiEvidenceDetailScreen(
              houseId: houseId,
              evidenceId: id.toString(),
            ),
          ),
        ),
      ),
    if (ids.length > 20) Text('Showing 20 / ${ids.length} evidence.'),
  ];

  @override
  Widget build(BuildContext context) {
    final metrics = profile['metrics'] as Map? ?? {};
    final preferences = profile['preference_profile'] as List?;
    return Column(
      children: [
        if (metrics.isNotEmpty)
          ExpansionTile(
            title: const Text('Metric Sources & Samples'),
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Only recorded application data is counted. Standard minutes are not measured working time.',
                ),
              ),
              for (final entry in metrics.entries)
                ExpansionTile(
                  title: Text(_labels[entry.key] ?? entry.key.toString()),
                  subtitle: Text(
                    '${_value(entry.value as Map)} · ${entry.value['sample_count']} samples'
                    '${entry.value['denominator'] == null ? '' : ' · ${entry.value['numerator']}/${entry.value['denominator']}'}',
                  ),
                  children: [
                    if (entry.value['quality'] == 'NO_OBSERVATIONS')
                      const Text(
                        'No evidence for this metric in the selected period.',
                      ),
                    ..._evidence(
                      context,
                      entry.value['evidence_ids'] as List? ?? [],
                    ),
                  ],
                ),
            ],
          ),
        if (preferences != null && preferences.isNotEmpty)
          ExpansionTile(
            title: const Text('Your Declared Preferences'),
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Saving the same choice does not increase the sample count. Completions and bounty views are not counted as preferences.',
                ),
              ),
              for (final item in preferences)
                ExpansionTile(
                  title: Text(item['chore_name']?.toString() ?? 'Chore'),
                  subtitle: Text(switch (item['current_declared']) {
                    'PREFERRED' => 'Currently preferred',
                    'DISLIKED' => 'Currently disliked',
                    _ => 'Preference Removed',
                  }),
                  children: [
                    ListTile(
                      title: Text(
                        'Preferred records ${item['positive_count']} · Disliked ${item['negative_count']}',
                      ),
                      subtitle: Text(
                        item['history_scope'] ==
                                'HOUSE_DECLARATIONS_NOT_SEASON_SCOPED'
                            ? 'Preferences belong to the household, not a season. Current status is shown separately.'
                            : item['smoothed_positive_score'] == null
                            ? 'No preference changes in the selected period.'
                            : 'Smoothed score: ${((item['smoothed_positive_score'] as num) * 100).toStringAsFixed(1)}% across ${item['sample_count']} samples. This is not confidence or acceptance probability.',
                      ),
                    ),
                    ..._evidence(context, item['evidence_ids'] as List? ?? []),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
