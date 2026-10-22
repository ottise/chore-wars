import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_states.dart';
import '../data/ai_repository.dart';

const evaluationMetricNames = {
  'coverage': 'Tỷ lệ việc xếp được',
  'coverage_count': 'Số việc xếp được',
  'task_count': 'Số việc cần xếp',
  'hard_violations': 'Phân công vi phạm',
  'karma_gap': 'Chênh Karma được giao',
  'karma_range_pct': 'Chênh Karma tương đối (%)',
  'preferred_count': 'Việc phù hợp sở thích khai báo',
  'disliked_count': 'Việc không được ưa thích',
  'workload_concentration': 'Mức tập trung effort',
  'assigned_count': 'Số việc đã có người nhận',
  'preference_eligible_count': 'Số phân công có sở thích khai báo',
  'declared_preference_alignment': 'Tỷ lệ phù hợp sở thích khai báo',
  'rotation_repeat_count': 'Số phân công lặp việc của tuần trước',
  'rotation_eligible_count': 'Số phân công đủ dữ liệu luân phiên',
  'rotation_repeat_rate': 'Tỷ lệ lặp việc tuần trước',
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
  if (value is! num || !value.isFinite) return 'Chưa xác định';
  if (ratio) return '${(value * 100).toStringAsFixed(1)}%';
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(3);
}

String evaluationDelta(String key, Object? value) =>
    evaluationRatioKeys.contains(key) && value is num
    ? '${(value * 100).toStringAsFixed(1)} điểm %'
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
        'Đánh giá và tiến bộ của AI',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Dữ liệu tích lũy và chất lượng đề xuất là hai điều khác nhau. So sánh luôn kèm số mẫu, phiên bản và giới hạn.',
      ),
      const SizedBox(height: 24),
      Text('Tiến trình học', style: Theme.of(context).textTheme.titleLarge),
      ExpansionTile(
        title: const Text('Lịch sử tích lũy theo cutoff'),
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
                      '${item['valid_event_count']} sự kiện · ${item['profile_evidence_count']} bằng chứng\n${item['telemetry_complete'] == true ? 'Đủ stream tại cutoff' : 'Chờ dữ liệu'}',
                    ),
                  ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Text('Chưa có snapshot đánh giá hoặc training.'),
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
              '${data['valid_event_count']} sự kiện hợp lệ · ${data['profile_evidence_count']} bằng chứng',
            ),
            const Text('Số lượng tăng chưa chứng minh đề xuất tốt hơn.'),
            Text(
              '${data['observed_interaction_count'] ?? 0} tín hiệu mở chi tiết đã ghi nhận; chưa chứng minh đã đọc, từ chối hoặc thích công việc.',
            ),
            for (final target in data['targets'] as List? ?? [])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${target['target']}: ${target['eligible_count']} mẫu đủ nhãn',
                ),
                subtitle: Text(
                  'Âm: ${(target['class_counts'] as Map?)?['0'] ?? 0} · Dương: ${(target['class_counts'] as Map?)?['1'] ?? 0}\n${target['product_data_eligible'] == true ? 'Đủ ngưỡng dữ liệu dự kiến; vẫn cần kiểm định' : 'Chưa đủ điều kiện dùng trong sản phẩm'}',
                ),
              ),
            Text(
              'Model: ${data['training_status'] == 'NO_APPROVED_MODEL' ? 'Chưa có model được duyệt' : data['training_status']}',
            ),
          ],
        ),
      ),
      const Divider(height: 36),
      ExpansionTile(
        title: const Text('Lỗi đồng bộ dữ liệu AI của nhà'),
        children: [
          _EvaluationData(
            house: widget.houseId,
            path: 'failures',
            builder: (data) => Column(
              children: [
                const Text(
                  'Chỉ hiển thị lỗi đã xác định thuộc nhà. Message chưa rõ nguồn được bộ phận vận hành xử lý.',
                ),
                for (final item in data['items'] as List? ?? [])
                  ListTile(
                    title: Text('${item['status']} · ${item['error_code']}'),
                    subtitle: Text(
                      'Mã đối chiếu: ${item['id']} · Đã replay ${item['replay_count']} lần',
                    ),
                  ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có lỗi thuộc nhà này.'),
                  ),
              ],
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: const Text('Thực nghiệm và phiên bản model'),
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
                      '${row['family'] ?? 'Chưa chọn model'} · Quality: ${row['quality_passed']} · Product: ${row['product_passed']}',
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
                  const Text('Chưa có lần thực nghiệm.'),
              ],
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: const Text('Tổng hợp các seed độc lập'),
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
                            'Còn thiếu seed: ${report['missing_seeds'] ?? []}',
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
                                    '${component.key}: ${evaluationDelta(metric.key.toString(), component.value['mean'])} · CI95: ${component.value['ci95'] ?? 'Chưa đủ cohort'} · n=${component.value['seed_count']}',
                                ].join('\n'),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Text(
                    'Chưa có báo cáo tổng hợp. Một seed không tạo CI giả.',
                  ),
              ],
            ),
          ),
        ],
      ),
      Text('Lịch sử đánh giá', style: Theme.of(context).textTheme.titleLarge),
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
                    'Chưa có lần đánh giá. Kết quả sẽ xuất hiện sau khi Evaluation Runner hoàn tất; màn hình không tạo số minh họa.',
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
                    child: const Text('Trước'),
                  ),
                  Text('Trang $page'),
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
    appBar: AppBar(title: const Text('Baseline và Adaptive')),
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
                label: Text(
                  'Dữ liệu giả lập — không phải kết quả người dùng thật',
                ),
                avatar: Icon(Icons.science_outlined),
              ),
            SelectableText('Run: ${run['id']}'),
            ExpansionTile(
              title: const Text('Chỉ số và mẫu số của lần chạy này'),
              children: [
                for (final entry in (run['metrics'] as Map).entries)
                  ListTile(
                    title: Text(
                      evaluationMetricNames[entry.key] ?? entry.key.toString(),
                    ),
                    subtitle: Text(
                      '${evaluationValue(entry.value['value'], ratio: evaluationRatioKeys.contains(entry.key))} · ${entry.value['status']}\nTử số: ${entry.value['numerator'] ?? 'Không áp dụng'} · Mẫu số: ${entry.value['denominator'] ?? 'Không áp dụng'}\nĐịnh nghĩa: ${entry.value['definition_version']}',
                    ),
                  ),
              ],
            ),
            Text('Policy: ${meta['policy_version']}'),
            Text('Model: ${meta['model_version'] ?? 'Không sử dụng model'}'),
            Text(
              'Input cutoff: ${meta['data_cutoff']}\nOutcome cutoff: ${meta['outcome_cutoff'] ?? 'Chưa quan sát kết quả thực hiện'}',
            ),
            Text(
              'Scenario: ${meta['scenario_id']} · Seed: ${meta['seed'] ?? 'Không áp dụng'}',
            ),
            const SizedBox(height: 24),
            _EvaluationData(
              house: houseId,
              path: 'evaluations/comparisons/${run['group_id']}',
              builder: (comparison) {
                if (comparison['status'] != 'COMPARABLE') {
                  return Text(
                    'Chưa thể so sánh: ${comparison['reason'] ?? comparison['status']}',
                  );
                }
                final rows = comparison['runs'] as List;
                final arms = {for (final r in rows) r['arm'] as String: r};
                final keys = (arms['B0']['metrics'] as Map).keys;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'B0: greedy · S0: search không lịch sử · H1: search có lịch sử',
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Chỉ số')),
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
                      title: const Text('Phần search và phần lịch sử đóng góp'),
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
                              'Search: ${evaluationDelta(entry.key.toString(), entry.value['search'])} · Lịch sử: ${evaluationDelta(entry.key.toString(), entry.value['history'])} · Tổng: ${evaluationDelta(entry.key.toString(), entry.value['total'])}',
                            ),
                          ),
                      ],
                    ),
                    const Text(
                      'Một seed chưa có khoảng tin cậy tổng hợp. Lịch tốt hơn do search chưa chứng minh tốt hơn nhờ học hành vi.',
                    ),
                    if (meta['outcome_metrics_status'] == 'NOT_OBSERVED')
                      const Text(
                        'Chưa có outcome: không kết luận giảm trễ hoặc giảm yêu cầu điều chỉnh.',
                      ),
                  ],
                );
              },
            ),
            const Divider(height: 36),
            Text(
              'Ví dụ lịch trước và sau',
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
                            Text('Lý do: ${sample['reason']}'),
                            for (final task in after)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  task['name']?.toString() ?? 'Công việc',
                                ),
                                subtitle: Text(
                                  '${before[task['id']]?['assigned_to'] ?? 'Chưa giao'} → ${task['assigned_to'] ?? 'Chưa giao'}\n${task['start_at'] ?? 'Chưa có giờ phù hợp'}',
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
    appBar: AppBar(title: const Text('Kết quả thực nghiệm')),
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
            const Chip(label: Text('Dữ liệu giả lập')),
          Text(
            'Model: ${data['family'] ?? 'Chưa chọn'} · Phiên bản: ${data['model_version'] ?? 'Chưa có'}',
          ),
          Text(
            'Quality gate: ${data['quality_passed']} · Product gate: ${data['product_passed']}',
          ),
          Text(
            'Lý do: ${data['reason'] ?? data['product_reason'] ?? 'Xem các chỉ số bên dưới'}',
          ),
          SelectableText(
            'Protocol: ${data['protocol']}\nRun: $runId\nNgưỡng: ${data['threshold'] ?? 'Không đạt hoặc chưa xác định'}',
          ),
          const Text(
            'Đạt kiểm định dự đoán chưa đủ điều kiện dùng trong sản phẩm. Model candidate không tự trở thành model production.',
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
