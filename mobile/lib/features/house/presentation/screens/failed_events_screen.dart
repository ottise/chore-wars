import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../data/repositories/failed_event_repository.dart';

class FailedEventsScreen extends ConsumerStatefulWidget {
  const FailedEventsScreen({super.key, required this.houseId});
  final String houseId;
  @override
  ConsumerState<FailedEventsScreen> createState() => _FailedEventsScreenState();
}

class _FailedEventsScreenState extends ConsumerState<FailedEventsScreen> {
  String? _status = 'FAILED';
  int _page = 1;
  String? _busy;
  ({String house, String? status, int page}) get _key =>
      (house: widget.houseId, status: _status, page: _page);
  void _refresh() => ref.invalidate(failedEventsProvider(_key));
  Future<void> _replay(FailedEventItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thử xử lý lại?'),
        content: const Text(
          'Hệ thống sẽ xử lý lại yêu cầu gốc. Bạn không cần thực hiện lại công việc hoặc xác nhận tiền.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = item.id);
    try {
      await ref
          .read(failedEventRepositoryProvider)
          .replay(widget.houseId, item.id);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã yêu cầu xử lý lại. Tải lại danh sách để xem kết quả.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  static String label(String value) => switch (value) {
    'FAILED' => 'Cần xử lý',
    'REPLAY_REQUESTED' => 'Đã yêu cầu thử lại',
    'RESOLVED' => 'Đã khôi phục',
    _ => value,
  };
  static String reason(String code) => switch (code) {
    'JsonException' => 'Thông tin yêu cầu không hợp lệ.',
    'InvalidDataException' => 'Chưa xác minh được dữ liệu của yêu cầu.',
    'DbUpdateException' => 'Dữ liệu chưa thể lưu. Hãy thử lại sau.',
    'TimeoutException' || 'IOException' => 'Kết nối hoặc tác vụ bị gián đoạn.',
    _ => 'Xử lý chưa thành công. Hệ thống đã lưu lỗi để kiểm tra.',
  };
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(failedEventsProvider(_key));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xử lý hệ thống'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theo dõi các yêu cầu xử lý bị gián đoạn trong nhà của bạn. Chỉ chủ nhà được yêu cầu thử lại.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_status),
                  initialValue: _status ?? 'ALL',
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: [
                    const DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                    for (final value in [
                      'FAILED',
                      'REPLAY_REQUESTED',
                      'RESOLVED',
                    ])
                      DropdownMenuItem(value: value, child: Text(label(value))),
                  ],
                  onChanged: (value) => setState(() {
                    _status = value == 'ALL' ? null : value;
                    _page = 1;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: data.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(error: error, onRetry: _refresh),
              data: (result) => RefreshIndicator(
                onRefresh: () async {
                  _refresh();
                  await ref.read(failedEventsProvider(_key).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (result.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text('Không có yêu cầu nào ở trạng thái này.'),
                        ),
                      ),
                    for (final item in result.items) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.status == 'RESOLVED'
                              ? Icons.check_circle_outline
                              : Icons.sync_problem_outlined,
                          color: item.status == 'RESOLVED'
                              ? AppTheme.green
                              : AppTheme.orange,
                        ),
                        title: Text(label(item.status)),
                        subtitle: Text(
                          '${item.topic}\n${DateFormat('dd/MM/yyyy HH:mm').format(item.lastFailedAt.toLocal())} · ${item.failureCount} lần lỗi · ${item.replayCount} lần thử lại',
                        ),
                        isThreeLine: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          item.status == 'RESOLVED'
                              ? 'Yêu cầu đã được xử lý thành công.'
                              : reason(item.errorCode),
                        ),
                      ),
                      if (item.status == 'FAILED')
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _busy == null
                                ? () => _replay(item)
                                : null,
                            icon: const Icon(Icons.replay),
                            label: Text(
                              _busy == item.id ? 'Đang gửi…' : 'Thử xử lý lại',
                            ),
                          ),
                        ),
                      const Divider(),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Trang trước',
                          onPressed: _page > 1 && _busy == null
                              ? () => setState(() => _page--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Trang $_page · ${result.total} yêu cầu'),
                        IconButton(
                          tooltip: 'Trang tiếp',
                          onPressed: _page * 20 < result.total && _busy == null
                              ? () => setState(() => _page++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
