import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_states.dart';
import '../data/ai_repository.dart';

const evaluationMetricNames = {
  'coverage': 'Task Coverage',
  'coverage_count': 'Scheduled Task Count',
  'task_count': 'Required Task Count',
  'hard_violations': 'Hard Constraint Violations',
  'karma_gap': 'Assigned Karma Gap',
  'karma_range_pct': 'Relative Karma Gap (%)',
  'preferred_count': 'Declared Preferred Tasks',
  'disliked_count': 'Disliked Tasks',
  'workload_concentration': 'Workload Concentration',
  'assigned_count': 'Assigned Task Count',
  'preference_eligible_count': 'Preference-Eligible Assignments',
  'declared_preference_alignment': 'Declared Preference Alignment',
  'rotation_repeat_count': 'Repeated Assignments from Last Week',
  'rotation_eligible_count': 'Rotation-Eligible Assignments',
  'rotation_repeat_rate': 'Weekly Repetition Rate',
};
const evaluationRatioKeys = {
  'coverage',
  'declared_preference_alignment',
  'rotation_repeat_rate',
  'late_rate',
  'on_time_completion_rate',
  'adjustment_request_rate',
};

String evaluationValue(Object? value, {bool ratio = false}) {
  if (value is! num || !value.isFinite) return 'Unknown';
  if (ratio) return '${(value * 100).toStringAsFixed(1)}%';
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(3);
}

String evaluationDelta(String key, Object? value) =>
    evaluationRatioKeys.contains(key) && value is num
    ? '${(value * 100).toStringAsFixed(1)} percentage points'
    : evaluationValue(value);

class _EvaluationData extends ConsumerWidget {
  const _EvaluationData({
    required this.house,
    required this.path,
    required this.builder,
  });
  final String house, path;
  final Widget Function(Map<String, dynamic>) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (house: house, path: path);
    return ref
        .watch(aiDataProvider(query))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(aiDataProvider(query)),
          ),
          data: builder,
        );
  }
}

class AiEvaluationDashboard extends ConsumerStatefulWidget {
  const AiEvaluationDashboard({super.key, required this.houseId});
  final String houseId;
  @override
  ConsumerState<AiEvaluationDashboard> createState() =>
      _AiEvaluationDashboardState();
}

class _AiEvaluationDashboardState extends ConsumerState<AiEvaluationDashboard> {
  int page = 1;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'AI Evaluation & Progress',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Data accumulation and recommendation quality are different. Comparisons include sample counts, versions and limitations.',
      ),
      const SizedBox(height: 24),
      Text('Learning Timeline', style: Theme.of(context).textTheme.titleLarge),
      ExpansionTile(
        title: const Text('Accumulation History by Cutoff'),
        children: [
          _EvaluationData(
            house: widget.houseId,
            path: 'learning/timeline',
            builder: (data) => Column(
              children: [
                for (final item in data['items'] as List? ?? [])
                  ListTile(
                    title: Text('${item['as_of']}'),
                    subtitle: Text(
                      '${item['valid_event_count']} events · ${item['profile_evidence_count']} evidence\n${item['telemetry_complete'] == true ? 'Stream complete at cutoff' : 'Awaiting data'}',
                    ),
                  ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Text('No evaluation or training snapshots yet.'),
              ],
            ),
          ),
        ],
      ),
      _EvaluationData(
        house: widget.houseId,
        path: 'learning-report',
        builder: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              '${data['valid_event_count']} valid events · ${data['profile_evidence_count']} evidence',
            ),
            const Text(
              'Higher counts alone do not prove better recommendations.',
            ),
            Text(
              '${data['observed_interaction_count'] ?? 0} recorded detail views; these do not establish that a chore was read, rejected or preferred.',
            ),
            for (final target in data['targets'] as List? ?? [])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${target['target']}: ${target['eligible_count']} eligible labeled samples',
                ),
                subtitle: Text(
                  'Negative: ${(target['class_counts'] as Map?)?['0'] ?? 0} · Positive: ${(target['class_counts'] as Map?)?['1'] ?? 0}\n${target['product_data_eligible'] == true ? 'Expected data threshold met; validation is still required' : 'Not eligible for product use'}',
                ),
              ),
            Text(
              'Model: ${data['training_status'] == 'NO_APPROVED_MODEL' ? 'No approved model' : data['training_status']}',
            ),
          ],
        ),
      ),
      const Divider(height: 36),
      ExpansionTile(
        title: const Text('Household AI Sync Failures'),
        children: [
          _EvaluationData(
            house: widget.houseId,
            path: 'failures',
            builder: (data) => Column(
              children: [
                const Text(
                  'Only failures attributed to this house are shown. Unattributed messages are handled by operations.',
                ),
                for (final item in data['items'] as List? ?? [])
                  ListTile(
                    title: Text('${item['status']} · ${item['error_code']}'),
                    subtitle: Text(
                      'Reference ID: ${item['id']} · Replayed ${item['replay_count']} times',
                    ),
                  ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No failures for this house.'),
                  ),
              ],
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: const Text('Experiments & Model Versions'),
        children: [
          _EvaluationData(
            house: widget.houseId,
            path: 'learning/training-runs',
            builder: (data) => Column(
              children: [
                for (final row in data['items'] as List? ?? [])
                  ListTile(
                    title: Text('${row['target']} · ${row['status']}'),
                    subtitle: Text(
                      '${row['family'] ?? 'No model selected'} · Quality: ${row['quality_passed']} · Product: ${row['product_passed']}',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AiTrainingRunScreen(
                          houseId: widget.houseId,
                          runId: row['run_id'].toString(),
                        ),
                      ),
                    ),
                  ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Text('No experiments yet.'),
              ],
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: const Text('Independent Seed Summary'),
        children: [
          _EvaluationData(
            house: widget.houseId,
            path: 'evaluations/aggregates',
            builder: (data) => Column(
              children: [
                for (final row in data['items'] as List? ?? [])
                  Builder(
                    builder: (context) {
                      final report = row['payload'] as Map;
                      return ExpansionTile(
                        title: Text(
                          '${report['status']} · ${report['eligible_seed_count'] ?? report['seed_count']} seed',
                        ),
                        subtitle: Text(
                          '${report['data_source']} · Bootstrap ${report['bootstrap_samples']}',
                        ),
                        children: [
                          Text(
                            'Missing seeds: ${report['missing_seeds'] ?? []}',
                          ),
                          Text(report['claim']?.toString() ?? ''),
                          for (final metric
                              in (report['metrics'] as Map? ?? {}).entries)
                            ListTile(
                              title: Text(
                                evaluationMetricNames[metric.key] ??
                                    metric.key.toString(),
                              ),
                              subtitle: Text(
                                [
                                  for (final component
                                      in (metric.value as Map).entries)
                                    '${component.key}: ${evaluationDelta(metric.key.toString(), component.value['mean'])} · CI95: ${component.value['ci95'] ?? 'Insufficient cohorts'} · n=${component.value['seed_count']}',
                                ].join('\n'),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Text(
                    'No aggregate report yet. A single seed does not produce an aggregate confidence interval.',
                  ),
              ],
            ),
          ),
        ],
      ),
      Text('Evaluation History', style: Theme.of(context).textTheme.titleLarge),
      _EvaluationData(
        house: widget.houseId,
        path: 'evaluations/runs?page=$page',
        builder: (data) {
          final rows = data['items'] as List? ?? [];
          return Column(
            children: [
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No evaluations yet. Results appear after the Evaluation Runner completes; no placeholder metrics are generated.',
                  ),
                ),
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.analytics_outlined,
                    color: AppTheme.purple,
                  ),
                  title: Text('${row['arm']} · ${row['status']}'),
                  subtitle: Text(
                    '${(row['metadata'] as Map?)?['data_source']} · ${(row['metadata'] as Map?)?['evaluation_mode']}\n${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(row['evaluated_at']).toLocal())}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/houses/${widget.houseId}/ai/evaluations/${row['id']}',
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: page > 1 ? () => setState(() => page--) : null,
                    child: const Text('Previous'),
                  ),
                  Text('Page $page'),
                  TextButton(
                    onPressed: page * 20 < (data['total'] as num? ?? 0)
                        ? () => setState(() => page++)
                        : null,
                    child: const Text('Sau'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ],
  );
}

class AiEvaluationRunScreen extends StatelessWidget {
  const AiEvaluationRunScreen({
    super.key,
    required this.houseId,
    required this.runId,
  });
  final String houseId, runId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Baseline vs Adaptive')),
    body: _EvaluationData(
      house: houseId,
      path: 'evaluations/runs/$runId',
      builder: (run) {
        final meta = Map<String, dynamic>.from(run['metadata'] as Map);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (meta['data_source'] == 'DEMO_SYNTHETIC')
              const Chip(
                label: Text('Synthetic data — not real user outcomes'),
                avatar: Icon(Icons.science_outlined),
              ),
            SelectableText('Run: ${run['id']}'),
            ExpansionTile(
              title: const Text('Metrics & Denominators for This Run'),
              children: [
                for (final entry in (run['metrics'] as Map).entries)
                  ListTile(
                    title: Text(
                      evaluationMetricNames[entry.key] ?? entry.key.toString(),
                    ),
                    subtitle: Text(
                      '${evaluationValue(entry.value['value'], ratio: evaluationRatioKeys.contains(entry.key))} · ${entry.value['status']}\nNumerator: ${entry.value['numerator'] ?? 'Not applicable'} · Denominator: ${entry.value['denominator'] ?? 'Not applicable'}\nDefinition: ${entry.value['definition_version']}',
                    ),
                  ),
              ],
            ),
            Text('Policy: ${meta['policy_version']}'),
            Text('Model: ${meta['model_version'] ?? 'No model used'}'),
            Text(
              'Input cutoff: ${meta['data_cutoff']}\nOutcome cutoff: ${meta['outcome_cutoff'] ?? 'Outcomes not yet observed'}',
            ),
            Text(
              'Scenario: ${meta['scenario_id']} · Seed: ${meta['seed'] ?? 'Not applicable'}',
            ),
            const SizedBox(height: 24),
            _EvaluationData(
              house: houseId,
              path: 'evaluations/comparisons/${run['group_id']}',
              builder: (comparison) {
                if (comparison['status'] != 'COMPARABLE') {
                  return Text(
                    'Comparison unavailable: ${comparison['reason'] ?? comparison['status']}',
                  );
                }
                final rows = comparison['runs'] as List;
                final arms = {for (final r in rows) r['arm'] as String: r};
                final keys = (arms['B0']['metrics'] as Map).keys;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'B0: greedy · S0: search without history · H1: search with history',
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Metric')),
                          DataColumn(label: Text('B0')),
                          DataColumn(label: Text('S0')),
                          DataColumn(label: Text('H1')),
                        ],
                        rows: [
                          for (final key in keys)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    evaluationMetricNames[key] ??
                                        key.toString(),
                                  ),
                                ),
                                for (final arm in ['B0', 'S0', 'H1'])
                                  DataCell(
                                    Text(
                                      evaluationValue(
                                        (arms[arm]['metrics'][key]
                                            as Map?)?['value'],
                                        ratio: evaluationRatioKeys.contains(
                                          key,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Search & History Contributions'),
                      children: [
                        for (final entry
                            in (comparison['deltas'] as Map).entries)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              evaluationMetricNames[entry.key] ??
                                  entry.key.toString(),
                            ),
                            subtitle: Text(
                              'Search: ${evaluationDelta(entry.key.toString(), entry.value['search'])} · History: ${evaluationDelta(entry.key.toString(), entry.value['history'])} · Total: ${evaluationDelta(entry.key.toString(), entry.value['total'])}',
                            ),
                          ),
                      ],
                    ),
                    const Text(
                      'A single seed has no aggregate confidence interval. Search improvements alone do not establish the benefit of learning from behavior.',
                    ),
                    if (meta['outcome_metrics_status'] == 'NOT_OBSERVED')
                      const Text(
                        'No outcomes yet: reduced lateness or adjustment requests cannot be claimed.',
                      ),
                  ],
                );
              },
            ),
            const Divider(height: 36),
            Text(
              'Before & After Schedule Examples',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _EvaluationData(
              house: houseId,
              path: 'evaluations/runs/$runId/examples',
              builder: (data) => Column(
                children: [
                  for (final item in data['items'] as List? ?? [])
                    Builder(
                      builder: (context) {
                        final sample = item['payload'] as Map;
                        final before = {
                          for (final t in sample['before'] as List? ?? [])
                            t['id']: t,
                        };
                        final after = sample['after'] as List? ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reason: ${sample['reason']}'),
                            for (final task in after)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  task['name']?.toString() ?? 'Chore',
                                ),
                                subtitle: Text(
                                  '${before[task['id']]?['assigned_to'] ?? 'Unassigned'} → ${task['assigned_to'] ?? 'Unassigned'}\n${task['start_at'] ?? 'No suitable time found'}',
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class AiTrainingRunScreen extends StatelessWidget {
  const AiTrainingRunScreen({
    super.key,
    required this.houseId,
    required this.runId,
  });
  final String houseId, runId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Experiment Results')),
    body: _EvaluationData(
      house: houseId,
      path: 'learning/training-runs/$runId',
      builder: (data) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${data['target']} · ${data['status']}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (data['data_source'] == 'DEMO_SYNTHETIC')
            const Chip(label: Text('Synthetic Data')),
          Text(
            'Model: ${data['family'] ?? 'Not selected'} · Version: ${data['model_version'] ?? 'Not available'}',
          ),
          Text(
            'Quality gate: ${data['quality_passed']} · Product gate: ${data['product_passed']}',
          ),
          Text(
            'Reason: ${data['reason'] ?? data['product_reason'] ?? 'See metrics below'}',
          ),
          SelectableText(
            'Protocol: ${data['protocol']}\nRun: $runId\nThreshold: ${data['threshold'] ?? 'Not passed or undetermined'}',
          ),
          const Text(
            'Passing prediction validation is not sufficient for product use. A candidate model does not automatically become a production model.',
          ),
          for (final key in [
            'readiness',
            'holdout',
            'baseline',
            'walk_forward',
            'inner_validation',
            'feature_encoding',
            'temporal_block_manifests',
          ])
            if (data[key] != null)
              ExpansionTile(
                title: Text(key),
                children: [SelectableText(data[key].toString())],
              ),
          for (final candidate in data['candidates'] as List? ?? [])
            ListTile(
              title: Text('${candidate['family']} ${candidate['config']}'),
              subtitle: Text(
                'Validation: ${candidate['validation']}\nFit: ${candidate['fit_ms']} ms · Predict: ${candidate['predict_ms']} ms',
              ),
            ),
        ],
      ),
    ),
  );
}
