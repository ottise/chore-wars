import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_provider.dart';
import '../../../core/utils/api_error_message.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../house/presentation/providers/house_providers.dart';
import '../data/ai_repository.dart';

class AiPlanningScreen extends ConsumerStatefulWidget {
  const AiPlanningScreen({
    super.key,
    required this.houseId,
    required this.kind,
    this.sourceOccurrenceId,
    this.initialRecord,
  });
  final String houseId, kind;
  final String? sourceOccurrenceId;
  final Map<String, dynamic>? initialRecord;
  @override
  ConsumerState<AiPlanningScreen> createState() => _AiPlanningScreenState();
}

class _AiPlanningScreenState extends ConsumerState<AiPlanningScreen> {
  final text = TextEditingController(),
      resources = TextEditingController(),
      budget = TextEditingController(text: '60');
  List<Map<String, dynamic>> seasons = [];
  Map<String, dynamic>? record;
  String? season, previous, error;
  final participants = <String>{};
  String request = const Uuid().v4();
  bool busy = false;
  int? epoch;
  bool get active => mounted && ref.read(sessionEpochProvider) == epoch;
  @override
  void initState() {
    super.initState();
    record = widget.initialRecord;
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    text.dispose();
    resources.dispose();
    budget.dispose();
    super.dispose();
  }

  Future<void> operation(Future<void> Function() body) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await body();
    } catch (e) {
      if (active) setState(() => error = apiErrorMessage(e));
    } finally {
      if (active) setState(() => busy = false);
    }
  }

  Future<void> load() => operation(() async {
    final response = await ref
        .read(dioProvider)
        .get('/houses/${widget.houseId}/seasons');
    if (!active) return;
    setState(
      () => seasons = (response.data as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList(),
    );
    final desired = widget.kind == 'EVOLUTION' ? 'DRAFT' : 'ACTIVE';
    final wanted = seasons
        .where(
          (s) =>
              s['status'] == desired ||
              s['status'] == (desired == 'DRAFT' ? 0 : 2),
        )
        .toList();
    if (wanted.isNotEmpty) {
      setState(() => season = wanted.first['id'].toString());
    }
  });
  @override
  Widget build(BuildContext context) {
    final current = ref.watch(sessionEpochProvider);
    epoch ??= current;
    if (epoch != current) {
      return const Scaffold(
        body: Center(child: Text('Phiên đã đổi. Hãy mở lại yêu cầu.')),
      );
    }
    final members =
        ref.watch(houseMembersProvider(widget.houseId)).asData?.value ?? [];
    final actor = ref.watch(userProfileProvider).asData?.value.id;
    final names = {
      for (final member in members) member.userId: member.displayName,
    };
    final result = record?['result'] as Map?;
    final frozen = busy || record != null;
    final isUrgent = widget.kind == 'URGENT';
    final title = switch (widget.kind) {
      'SWAP' => 'Tìm phương án đổi việc',
      'REPLAN' => 'Sắp lại lịch tương lai',
      'EVOLUTION' => 'Lịch cho mùa tiếp theo',
      _ => 'Chiến dịch khẩn cấp',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Xem phương án trước khi gửi. Các thay đổi đang diễn ra cần đúng người liên quan đồng thuận; lịch nháp vẫn qua duyệt mùa.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: season,
            decoration: const InputDecoration(labelText: 'Mùa làm việc'),
            items: [
              for (final s in seasons.where(
                (s) => widget.kind == 'EVOLUTION'
                    ? (s['status'] == 0 || s['status'] == 'DRAFT')
                    : (s['status'] == 2 || s['status'] == 'ACTIVE'),
              ))
                DropdownMenuItem(
                  value: s['id'].toString(),
                  child: Text(s['name']?.toString() ?? s['id'].toString()),
                ),
            ],
            onChanged: frozen
                ? null
                : (value) => setState(() => season = value),
          ),
          if (widget.kind == 'EVOLUTION')
            DropdownButtonFormField<String>(
              initialValue: previous,
              decoration: const InputDecoration(
                labelText: 'Mùa đã kết thúc làm nguồn đối chiếu',
              ),
              items: [
                for (final s in seasons.where(
                  (s) => s['status'] == 3 || s['status'] == 'COMPLETED',
                ))
                  DropdownMenuItem(
                    value: s['id'].toString(),
                    child: Text(s['name']?.toString() ?? s['id'].toString()),
                  ),
              ],
              onChanged: frozen
                  ? null
                  : (value) => setState(() => previous = value),
            ),
          if (widget.kind == 'SWAP')
            const Text(
              'Chỉ gợi ý đổi việc còn hợp lệ. Hai người duyệt lại trước khi đổi trách nhiệm.',
            ),
          if (isUrgent) ...[
            TextField(
              controller: text,
              enabled: !frozen,
              maxLines: 4,
              maxLength: 8000,
              decoration: const InputDecoration(
                labelText: 'Cần hoàn thành điều gì?',
              ),
            ),
            TextField(
              controller: budget,
              enabled: !frozen,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ngân sách thời gian (phút)',
              ),
            ),
            TextField(
              controller: resources,
              enabled: !frozen,
              decoration: const InputDecoration(
                labelText: 'Nguồn lực có sẵn, phân tách bằng dấu phẩy',
                hintText: 'máy hút bụi, bồn rửa',
              ),
            ),
            const Text('Người tham gia (bao gồm bạn):'),
            for (final member in members)
              CheckboxListTile(
                value:
                    member.userId == actor ||
                    participants.contains(member.userId),
                title: Text(member.displayName),
                onChanged: frozen || member.userId == actor
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          participants.add(member.userId);
                        } else {
                          participants.remove(member.userId);
                        }
                      }),
              ),
          ],
          if (record == null)
            FilledButton.icon(
              onPressed: busy || season == null
                  ? null
                  : () => operation(() async {
                      if (widget.kind == 'EVOLUTION' && previous == null) {
                        throw StateError('Chọn mùa nguồn trước.');
                      }
                      final path = switch (widget.kind) {
                        'SWAP' => 'schedules/swap',
                        'REPLAN' => 'schedules/replan',
                        'EVOLUTION' => 'seasons/evolve',
                        _ => 'urgent/plan',
                      };
                      final response = await ref
                          .read(aiRepositoryProvider)
                          .post(widget.houseId, path, {
                            'clientRequestId': request,
                            'seasonId': season,
                            'sourceOccurrenceId': widget.sourceOccurrenceId,
                            'sourceSeasonId': previous,
                            if (isUrgent) ...{
                              'text': text.text,
                              'deadlineMinutes': int.tryParse(budget.text) ?? 0,
                              'participantIds': {
                                ...participants,
                                ?actor,
                              }.toList(),
                              'resources': resources.text
                                  .split(',')
                                  .map((s) => s.trim())
                                  .where((s) => s.isNotEmpty)
                                  .toSet()
                                  .toList(),
                            },
                          });
                      if (active) setState(() => record = response);
                    }),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Tạo bản xem trước'),
            ),
          if (record != null) ...[
            const Divider(height: 32),
            Text('Trạng thái: ${record!['status']}'),
            for (final change in record!['availability_changes'] as List? ?? [])
              Text(
                'Lịch rảnh đề xuất: ${change['LocalDate'] ?? change['localDate']} · ${change['Slots'] ?? change['slots']}',
              ),
            if (result?['reason'] != null) Text(result!['reason'].toString()),
            if (result?['status'] != null) Text(result!['status'].toString()),
            for (final field in result?['missing_fields'] as List? ?? [])
              Text('Cần làm rõ: $field'),
            for (final task in result?['tasks'] as List? ?? [])
              ListTile(
                title: Text(task['name']?.toString() ?? 'Công việc'),
                subtitle: Text(
                  '${names[task['assigned_to']] ?? 'Chưa xếp'} · ${task['start_at'] ?? 'Chưa xếp giờ'}${task['end_at'] == null ? '' : ' → ${task['end_at']}'}\n${(task['dependencies'] as List? ?? []).isEmpty ? '' : 'Phụ thuộc: ${task['dependencies']}'}',
                ),
              ),
            for (final key in result?['unplaced'] as List? ?? [])
              Text('Chưa xếp được: $key'),
            if (record!['status'] == 'READY' &&
                result?['status'] != 'INFEASIBLE' &&
                result?['status'] != 'NEEDS_CLARIFICATION')
              FilledButton(
                onPressed: busy
                    ? null
                    : () => operation(() async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Gửi phương án đã xem?'),
                            content: const Text(
                              'Hệ thống sẽ kiểm tra lại lịch hiện tại và yêu cầu đúng người liên quan xác nhận. Nếu dữ liệu đổi, bạn cần xem phương án mới.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Hủy'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Đồng ý gửi'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !active) return;
                        final response = await ref
                            .read(aiRepositoryProvider)
                            .post(
                              widget.houseId,
                              'recommendations/${record!['id']}/accept',
                              {},
                            );
                        if (active) setState(() => record = response);
                        ref.invalidate(activeSeasonProvider(widget.houseId));
                      }),
                child: const Text('Gửi phương án đã xem'),
              ),
            if (record!['proposal_id'] != null)
              const Text(
                'Đã tạo thẻ đồng thuận trong chat nhà. Mọi thay đổi chỉ áp dụng khi đủ xác nhận.',
              ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      record = null;
                      request = const Uuid().v4();
                    }),
              child: const Text('Tạo yêu cầu khác'),
            ),
          ],
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
