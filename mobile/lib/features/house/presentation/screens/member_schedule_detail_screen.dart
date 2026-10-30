import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';

class MemberScheduleDetailScreen extends ConsumerStatefulWidget {
  const MemberScheduleDetailScreen({
    required this.houseId,
    required this.userId,
    required this.name,
    required this.from,
    required this.to,
    this.seasonId,
    super.key,
  });
  final String houseId, userId, name, from, to;
  final String? seasonId;
  @override
  ConsumerState<MemberScheduleDetailScreen> createState() => _State();
}

class _State extends ConsumerState<MemberScheduleDetailScreen> {
  final List<dynamic> _items = [];
  int _page = 0, _total = 0;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final response = await ref
          .read(dioProvider)
          .get(
            '/houses/${widget.houseId}/members/${widget.userId}/schedule',
            queryParameters: {
              'from': widget.from,
              'to': widget.to,
              'season': widget.seasonId,
              'page': _page + 1,
              'pageSize': 30,
            },
          );
      if (mounted) {
        setState(() {
          _items.addAll(response.data['items']);
          _total = response.data['total'];
          _page++;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String date(Object? value) => value == null
      ? 'Not recorded'
      : '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(value.toString()).toUtc().add(const Duration(hours: 7)))} (Vietnam)';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.name} · Schedule',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (!_busy && _items.isEmpty && _error == null)
          const Text('No chores in this period.'),
        for (final item in _items)
          Card(
            child: ListTile(
              title: Text(item['choreName']),
              subtitle: Text(
                'Due: ${date(item['dueDate'])}\nStatus: ${item['status']}\nAssigned to: ${item['assignedUserDisplayName'] ?? 'Unassigned'}\nCompleted: ${date(item['completedAt'])}\n${item['completedByUserId'] == widget.userId ? 'Completed by this member' : 'Current assignment / completion attributed separately'}${item['evidenceId'] != null ? ' · Photo evidence' : ''}',
              ),
              isThreeLine: true,
              onTap: () => context.push(
                '/houses/${widget.houseId}/chores/${item['id']}',
              ),
            ),
          ),
        if (!_busy && (_items.length < _total || _error != null))
          TextButton(
            onPressed: _load,
            child: Text(_error == null ? 'Load more' : 'Try again'),
          ),
      ],
    ),
  );
}
