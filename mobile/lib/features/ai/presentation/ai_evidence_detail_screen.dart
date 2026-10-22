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
      appBar: AppBar(title: const Text('Bằng chứng đóng góp')),
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
                    const Chip(label: Text('Bằng chứng giả lập')),
                  Text(switch (data['event_type']) {
                    'occurrence.upsert' => 'Kết quả công việc',
                    'episode.upsert' => 'Lịch sử nhận trách nhiệm',
                    'ledger.upsert' => 'Giao dịch Karma',
                    'ranking.upsert' => 'Kết quả xếp hạng mùa',
                    'bounty.upsert' => 'Lịch sử đăng bounty',
                    'proposal.upsert' => 'Yêu cầu điều chỉnh',
                    'payment.upsert' => 'Xác nhận thanh toán',
                    _ => 'Bằng chứng nghiệp vụ',
                  }, style: Theme.of(context).textTheme.headlineSmall),
                  Text('Ghi nhận lúc ${data['recorded_at']}'),
                  for (final entry in payload.entries)
                    ListTile(
                      title: Text(
                        {
                              'name': 'Công việc',
                              'minutes': 'Effort chuẩn (phút)',
                              'karma': 'Karma theo việc',
                              'completed_at': 'Hoàn thành lúc',
                              'completed_by': 'Người thực sự hoàn thành',
                              'reason': 'Nguồn nhận trách nhiệm',
                              'started_at': 'Nhận trách nhiệm lúc',
                              'ended_at': 'Kết thúc trách nhiệm lúc',
                              'amount': data['event_type'] == 'ledger.upsert'
                                  ? 'Lượng Karma'
                                  : 'Số tiền (VND)',
                              'type': 'Loại giao dịch',
                              'rank': 'Thứ hạng',
                              'member_count': 'Số thành viên xếp hạng',
                              'total_karma': 'Karma của mùa',
                              'chores_completed': 'Số việc hoàn thành',
                            }[entry.key] ??
                            entry.key.toString(),
                      ),
                      subtitle: SelectableText(
                        entry.value?.toString() ?? 'Chưa xác định',
                      ),
                    ),
                  if (occurrence != null)
                    TextButton(
                      onPressed: () =>
                          context.push('/houses/$houseId/chores/$occurrence'),
                      child: const Text('Mở công việc gốc'),
                    ),
                  ExpansionTile(
                    title: const Text('Thông tin truy vết'),
                    children: [
                      SelectableText(
                        'Event: $evidenceId\nThứ tự nguồn: ${data['house_sequence']}',
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
