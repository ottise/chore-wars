import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_states.dart';
import '../data/ai_repository.dart';

class AiRiskInsightsScreen extends ConsumerWidget {
  const AiRiskInsightsScreen({super.key, required this.houseId});
  final String houseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (house: houseId, path: 'me/risk-insights');
    return Scaffold(
      appBar: AppBar(title: const Text('My Responsibilities')),
      body: ref
          .watch(aiDataProvider(query))
          .when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(aiDataProvider(query)),
            ),
            data: (data) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Only responsibilities you have accepted are shown. Estimates use information available at acceptance and do not change schedules, points or payments.',
                ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No eligible open responsibilities.'),
                  ),
                for (final row in data['items'] as List? ?? [])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(switch (row['status']) {
                            'PREDICTED' => 'Estimate at Acceptance',
                            'NO_APPROVED_MODEL' => 'No approved model',
                            'WAITING_FOR_TELEMETRY' => 'Awaiting Sync',
                            'INSUFFICIENT_SOURCE_CONTEXT' =>
                              'Missing Source Evidence',
                            _ => 'Not Eligible for Evaluation',
                          }),
                          if (row['p_late'] is num) ...[
                            Text(
                              'Estimated lateness risk: ${((row['p_late'] as num) * 100).toStringAsFixed(1)}%',
                            ),
                            Text(
                              'Context at acceptance: ${row['logical_prediction_time']}',
                            ),
                            Text(
                              'Prediction executed at: ${row['executed_at']}',
                            ),
                            Text(
                              'Model: ${row['model_version']} · Source: ${row['data_source']}',
                            ),
                            if (row['data_source'] == 'DEMO_SYNTHETIC')
                              const Text(
                                'Synthetic data; effectiveness for real users is not established.',
                              ),
                          ],
                          if (row['occurrence_id'] != null)
                            TextButton(
                              onPressed: () => context.push(
                                '/houses/$houseId/chores/${row['occurrence_id']}',
                              ),
                              child: const Text('Open Chore'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}
