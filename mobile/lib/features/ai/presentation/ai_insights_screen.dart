import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_states.dart';
import '../data/ai_repository.dart';
import 'ai_availability_review_screen.dart';

class AiInsightsScreen extends ConsumerWidget {
  const AiInsightsScreen({super.key, required this.houseId, this.chat = false});
  final String houseId;
  final bool chat;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (
      house: houseId,
      path: chat ? 'chat/insights' : 'bounties/suggestions',
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          chat ? 'Gợi ý riêng từ tin nhắn' : 'Bounty phù hợp với bạn',
        ),
      ),
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
                Text(
                  chat
                      ? 'Chỉ bạn thấy kết quả từ tin nhắn của mình. Đây là tín hiệu cần xác nhận, chưa là lịch bận hoặc thay đổi trách nhiệm.'
                      : 'Gợi ý tự nguyện dựa trên lịch rảnh, sở thích khai báo và kinh nghiệm. Nhận nhiều bounty không làm tăng phần việc bắt buộc.',
                ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Chưa có gợi ý đủ điều kiện.'),
                  ),
                for (final item in data['items'] as List? ?? [])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: chat
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Trạng thái: ${item['status']}'),
                                Text(
                                  (item['result'] as Map?)?['summary']
                                          ?.toString() ??
                                      '',
                                ),
                                for (final quote
                                    in (item['result']
                                                as Map?)?['evidence_quotes']
                                            as List? ??
                                        [])
                                  Text('“$quote”'),
                                for (final missing
                                    in (item['result']
                                                as Map?)?['missing_fields']
                                            as List? ??
                                        [])
                                  Text('Cần làm rõ: $missing'),
                                Text('Nguồn tin nhắn: ${item['message_id']}'),
                                if (item['status'] == 'READY' &&
                                    (item['result'] as Map?)?['availability']
                                        is Map)
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AiAvailabilityReviewScreen(
                                              houseId: houseId,
                                              candidate:
                                                  (item['result']
                                                          as Map)['availability']
                                                      as Map,
                                              insightId: item['id'].toString(),
                                            ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Xem lại và xác nhận lịch bận / rảnh',
                                    ),
                                  ),
                                const Text(
                                  'Để xác nhận thay đổi, mở phần khai báo lịch rảnh hoặc tạo đề xuất và xem lại với người liên quan.',
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name']?.toString() ?? 'Công việc',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  '${NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(item['amount'])} · ${item['declared_preference']}',
                                ),
                                Text('Có thể xếp từ ${item['possible_start']}'),
                                Text(
                                  'Lý do: ${item['reason']} · ${item['historical_completions_capped']} lần hoàn thành trước (giới hạn 20)',
                                ),
                                TextButton(
                                  onPressed: () => context.push(
                                    '/bounties/${item['bounty_id']}?houseId=$houseId',
                                  ),
                                  child: const Text(
                                    'Xem bounty và quyết định nhận',
                                  ),
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
