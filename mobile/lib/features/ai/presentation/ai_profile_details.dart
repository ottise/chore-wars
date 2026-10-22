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
    'completed_count': 'Công việc hoàn thành',
    'standard_minutes': 'Khối lượng chuẩn',
    'snapshot_karma': 'Karma của việc đã hoàn thành',
    'responsibility_count': 'Lượt nhận trách nhiệm',
    'on_time_episode_rate': 'Hoàn thành đúng hạn',
    'bounty_claim_count': 'Lượt nhận qua bounty',
    'bounty_occurrence_count': 'Việc khác nhau nhận qua bounty',
    'bounty_self_completion_rate': 'Tự hoàn thành việc nhận qua bounty',
    'bounty_posted_count': 'Bounty đã đăng',
    'mean_normalized_rank': 'Thứ hạng chuẩn hóa trung bình',
  };

  String _value(Map metric) {
    final value = metric['value'];
    if (value == null) return 'Chưa đủ mẫu';
    if (metric['unit'] == 'ratio' && value is num) {
      return '${(value * 100).toStringAsFixed(1)}%';
    }
    return '$value${metric['unit'] == 'standard_minutes' ? ' phút chuẩn' : ''}';
  }

  List<Widget> _evidence(BuildContext context, List ids) => [
    for (final id in ids.take(20))
      ListTile(
        dense: true,
        title: const Text('Xem bằng chứng của chỉ số'),
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
    if (ids.length > 20) Text('Hiển thị 20 / ${ids.length} bằng chứng.'),
  ];

  @override
  Widget build(BuildContext context) {
    final metrics = profile['metrics'] as Map? ?? {};
    final preferences = profile['preference_profile'] as List?;
    return Column(
      children: [
        if (metrics.isNotEmpty)
          ExpansionTile(
            title: const Text('Nguồn và mẫu của từng chỉ số'),
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Chỉ tính dữ liệu ứng dụng đã ghi nhận. Phút chuẩn không phải thời gian lao động đo được.',
                ),
              ),
              for (final entry in metrics.entries)
                ExpansionTile(
                  title: Text(_labels[entry.key] ?? entry.key.toString()),
                  subtitle: Text(
                    '${_value(entry.value as Map)} · ${entry.value['sample_count']} mẫu'
                    '${entry.value['denominator'] == null ? '' : ' · ${entry.value['numerator']}/${entry.value['denominator']}'}',
                  ),
                  children: [
                    if (entry.value['quality'] == 'NO_OBSERVATIONS')
                      const Text(
                        'Chưa có bằng chứng cho chỉ số trong khoảng này.',
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
            title: const Text('Sở thích bạn đã khai báo'),
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Lưu lại cùng một lựa chọn không tăng số mẫu. Việc đã làm và lượt mở bounty không được tính là thích hoặc không thích.',
                ),
              ),
              for (final item in preferences)
                ExpansionTile(
                  title: Text(item['chore_name']?.toString() ?? 'Công việc'),
                  subtitle: Text(switch (item['current_declared']) {
                    'PREFERRED' => 'Hiện khai báo: thích',
                    'DISLIKED' => 'Hiện khai báo: không thích',
                    _ => 'Đã xóa khai báo',
                  }),
                  children: [
                    ListTile(
                      title: Text(
                        'Ghi nhận thích ${item['positive_count']} · Không thích ${item['negative_count']}',
                      ),
                      subtitle: Text(
                        item['history_scope'] ==
                                'HOUSE_DECLARATIONS_NOT_SEASON_SCOPED'
                            ? 'Khai báo theo nhà, không gán lịch sử này vào một mùa. Trạng thái hiện tại được hiển thị riêng.'
                            : item['smoothed_positive_score'] == null
                            ? 'Chưa có thay đổi khai báo trong khoảng đã chọn.'
                            : 'Điểm làm trơn: ${((item['smoothed_positive_score'] as num) * 100).toStringAsFixed(1)}% trên ${item['sample_count']} mẫu. Đây không phải độ tin cậy hay xác suất nhận việc.',
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
