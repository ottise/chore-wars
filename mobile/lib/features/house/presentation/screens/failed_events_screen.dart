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
        title: const Text('Retry Processing?'),
        content: const Text(
          'The system will retry the original request. You do not need to repeat the chore or confirm the payment again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
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
          content: Text('Retry requested. Refresh the list to see the result.'),
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
    'FAILED' => 'Needs Review',
    'REPLAY_REQUESTED' => 'Retry Requested',
    'RESOLVED' => 'Recovered',
    _ => value,
  };
  static String reason(String code) => switch (code) {
    'JsonException' => 'The request information is invalid.',
    'InvalidDataException' => 'The request data could not be verified.',
    'DbUpdateException' => 'Unable to save data. Please try again later.',
    'TimeoutException' ||
    'IOException' => 'The connection or operation was interrupted.',
    _ => 'Processing failed. The error was recorded for investigation.',
  };
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(failedEventsProvider(_key));
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Recovery'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
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
                  'Track interrupted household requests. Only the owner can request a retry.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_status),
                  initialValue: _status ?? 'ALL',
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(value: 'ALL', child: Text('All')),
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
                          child: Text('No requests with this status.'),
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
                          '${item.topic}\n${DateFormat('dd/MM/yyyy HH:mm').format(item.lastFailedAt.toLocal())} · ${item.failureCount} failures · ${item.replayCount} retries',
                        ),
                        isThreeLine: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          item.status == 'RESOLVED'
                              ? 'The request was processed successfully.'
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
                              _busy == item.id
                                  ? 'Sending…'
                                  : 'Retry Processing',
                            ),
                          ),
                        ),
                      const Divider(),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Previous Page',
                          onPressed: _page > 1 && _busy == null
                              ? () => setState(() => _page--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page $_page · ${result.total} requests'),
                        IconButton(
                          tooltip: 'Next Page',
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
