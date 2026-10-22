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
      appBar: AppBar(title: const Text('Trách nhiệm của tôi')),
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
                  'Chỉ xem các trách nhiệm bạn đã nhận. Ước lượng dùng thông tin lúc nhận trách nhiệm và không tự thay đổi lịch, điểm hoặc tiền.',
                ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Hiện chưa có trách nhiệm còn mở đủ điều kiện.',
                    ),
                  ),
                for (final row in data['items'] as List? ?? [])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(switch (row['status']) {
                            'PREDICTED' => 'Ước lượng tại thời điểm nhận việc',
                            'NO_APPROVED_MODEL' => 'Chưa có model được duyệt',
                            'WAITING_FOR_TELEMETRY' => 'Đang chờ đồng bộ',
                            'INSUFFICIENT_SOURCE_CONTEXT' =>
                              'Thiếu bằng chứng gốc',
                            _ => 'Chưa đủ điều kiện đánh giá',
                          }),
                          if (row['p_late'] is num) ...[
                            Text(
                              'Nguy cơ trễ ước lượng: ${((row['p_late'] as num) * 100).toStringAsFixed(1)}%',
                            ),
                            Text(
                              'Context lúc nhận việc: ${row['logical_prediction_time']}',
                            ),
                            Text('Thực thi dự đoán: ${row['executed_at']}'),
                            Text(
                              'Model: ${row['model_version']} · Nguồn: ${row['data_source']}',
                            ),
                            if (row['data_source'] == 'DEMO_SYNTHETIC')
                              const Text(
                                'Dữ liệu giả lập; chưa chứng minh hiệu quả với người dùng thật.',
                              ),
                          ],
                          if (row['occurrence_id'] != null)
                            TextButton(
                              onPressed: () => context.push(
                                '/houses/$houseId/chores/${row['occurrence_id']}',
                              ),
                              child: const Text('Mở công việc'),
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
