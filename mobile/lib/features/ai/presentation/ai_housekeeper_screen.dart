import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/session_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../core/widgets/app_states.dart';
import '../../house/domain/entities/house_models.dart';
import '../../house/presentation/providers/house_providers.dart';
import '../data/ai_repository.dart';
import 'ai_evaluation_dashboard_screen.dart';
import 'ai_voice_controls.dart';
import 'ai_planning_screen.dart';
import 'ai_insights_screen.dart';
import 'ai_risk_insights_screen.dart';
import 'ai_evidence_detail_screen.dart';
import 'ai_availability_review_screen.dart';
import 'ai_profile_details.dart';

class AiHousekeeperScreen extends ConsumerWidget {
  const AiHousekeeperScreen({super.key, required this.houseId});
  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final house = ref.watch(houseDetailProvider(houseId));
    return house.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Quản gia AI')),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(houseDetailProvider(houseId)),
        ),
      ),
      data: (value) {
        final owner = value.myRole == HouseRole.owner;
        return DefaultTabController(
          length: owner ? 4 : 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Quản gia AI'),
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  const Tab(text: 'Đóng góp'),
                  if (owner) const Tab(text: 'Đánh giá'),
                  const Tab(text: 'Đề xuất'),
                  const Tab(text: 'Cài đặt'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _Profiles(
                  key: ValueKey((houseId, ref.watch(sessionEpochProvider))),
                  houseId: houseId,
                ),
                if (owner) AiEvaluationDashboard(houseId: houseId),
                _Commands(
                  key: ValueKey(ref.watch(sessionEpochProvider)),
                  houseId: houseId,
                  owner: owner,
                ),
                _Settings(houseId: houseId, owner: owner),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AiDataView extends ConsumerWidget {
  const AiDataView({
    super.key,
    required this.houseId,
    required this.path,
    required this.builder,
  });
  final String houseId, path;
  final Widget Function(Map<String, dynamic>) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (house: houseId, path: path);
    return ref
        .watch(aiDataProvider(key))
        .when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(aiDataProvider(key)),
          ),
          data: builder,
        );
  }
}

class _Profiles extends ConsumerStatefulWidget {
  const _Profiles({super.key, required this.houseId});
  final String houseId;
  @override
  ConsumerState<_Profiles> createState() => _ProfilesState();
}

class _ProfilesState extends ConsumerState<_Profiles> {
  String period = 'all-time';
  String? seasonId;
  @override
  Widget build(BuildContext context) {
    final houseId = widget.houseId;
    final seasons = ref.watch(aiSeasonsProvider(houseId)).asData?.value ?? [];
    final members =
        ref.watch(houseMembersProvider(houseId)).asData?.value ?? [];
    final names = {for (final m in members) m.userId: m.displayName};
    return AiDataView(
      houseId: houseId,
      path:
          'profiles?period=$period${period == 'season' && seasonId != null ? '&seasonId=$seasonId' : ''}',
      builder: (data) {
        final items = data['items'] as List? ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: period,
              decoration: const InputDecoration(labelText: 'Khoảng thời gian'),
              items: [
                for (final entry in {
                  'all-time': 'Toàn bộ lịch sử',
                  '30d': '30 ngày gần nhất',
                  '90d': '90 ngày gần nhất',
                  if (seasons.isNotEmpty) 'season': 'Theo mùa',
                }.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() {
                period = value ?? 'all-time';
                if (period == 'season') {
                  seasonId ??= seasons.first['id'].toString();
                }
              }),
            ),
            if (period == 'season')
              DropdownButtonFormField<String>(
                initialValue: seasonId,
                decoration: const InputDecoration(labelText: 'Mùa'),
                items: [
                  for (final item in seasons)
                    DropdownMenuItem(
                      value: item['id'].toString(),
                      child: Text(item['name']?.toString() ?? 'Mùa'),
                    ),
                ],
                onChanged: (value) => setState(() => seasonId = value),
              ),
            const SizedBox(height: 16),
            Text(
              'Ghi nhận việc đã làm',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Khối lượng chuẩn và lịch sử nhận trách nhiệm giúp giải thích đóng góp. Chúng không đánh giá tính cách hoặc tạo nghĩa vụ làm thêm.',
            ),
            if (data['telemetry_complete'] == false)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Dữ liệu đang được đồng bộ. Chưa đủ để kết luận.',
                  style: TextStyle(color: AppTheme.orange),
                ),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Chưa có hoạt động đủ bằng chứng. Hoàn thành công việc theo luồng thông thường để bắt đầu ghi nhận.',
                ),
              ),
            for (final raw in items) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        names[raw['member_id']] ?? 'Thành viên',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${raw['completed_count']} việc thực sự hoàn thành · ${raw['standard_minutes']} phút effort chuẩn',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bounty: nhận ${raw['bounty_occurrence_count']} việc, tự hoàn thành ${raw['bounty_self_completed']}, người khác hoàn thành ${raw['bounty_other_completed']}.',
                      ),
                      Text(
                        'Chưa đến hạn: ${raw['bounty_pending']} · Quá hạn còn mở: ${raw['bounty_overdue_open']}',
                      ),
                      ExpansionTile(
                        title: const Text('Trách nhiệm và điểm số'),
                        children: [
                          ListTile(
                            title: Text(
                              'Đã nhận trách nhiệm: ${raw['responsibility_count'] ?? 0} lượt',
                            ),
                            subtitle: Text(
                              'Nguồn: ${raw['responsibility_source_counts'] ?? {}}\nHoàn thành theo nguồn: ${raw['completion_source_counts'] ?? {}}',
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'Đúng hạn: ${raw['on_time_episode_count'] ?? 0} / ${raw['on_time_episode_denominator'] ?? 0} episode đủ kết quả',
                            ),
                            subtitle: Text(
                              'Còn chờ: ${raw['pending_episode_count'] ?? 0} · Bị loại/censored: ${raw['censored_episode_count'] ?? 0}',
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'Đề nghị điều chỉnh: ${raw['adjustment_request_status_counts'] ?? {}}',
                            ),
                            subtitle: const Text(
                              'Phân biệt yêu cầu, chấp thuận và từ chối; không suy ra động cơ.',
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'Đứng đầu ${raw['season_wins'] ?? 0} · Đứng cuối ${raw['season_bottoms'] ?? 0} / ${raw['ranked_seasons'] ?? 0} mùa',
                            ),
                            subtitle: Text(
                              'Các khoản Karma: ${raw['ledger_breakdown'] ?? {}}',
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'Đã đăng ${raw['bounty_posted_count'] ?? 0} bounty',
                            ),
                            subtitle: Text(
                              'Mức thưởng đã đăng: ${(raw['bounty_posted_amounts'] as List? ?? []).take(20).join(', ')}',
                            ),
                          ),
                        ],
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          '${(raw['evidence_ids'] as List? ?? []).length} bằng chứng nghiệp vụ',
                        ),
                        children: [
                          for (final id
                              in (raw['evidence_ids'] as List? ?? []).take(20))
                            ListTile(
                              dense: true,
                              title: const Text('Mở bằng chứng nghiệp vụ'),
                              subtitle: Text(id.toString()),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => AiEvidenceDetailScreen(
                                    houseId: houseId,
                                    evidenceId: id.toString(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      AiProfileDetails(
                        houseId: houseId,
                        profile: Map<String, dynamic>.from(raw as Map),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Commands extends ConsumerStatefulWidget {
  const _Commands({super.key, required this.houseId, required this.owner});
  final String houseId;
  final bool owner;
  @override
  ConsumerState<_Commands> createState() => _CommandsState();
}

class _CommandsState extends ConsumerState<_Commands> {
  final input = TextEditingController();
  bool busy = false;
  String? error, requestId;
  Map<String, dynamic>? recommendation, interpretation;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() callback) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await callback();
    } catch (e) {
      if (mounted) setState(() => error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final season = ref
        .watch(activeSeasonProvider(widget.houseId))
        .asData
        ?.value;
    final result = recommendation?['result'] as Map?;
    final tasks = result?['tasks'] as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Xem trước rồi quyết định',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'AI không tự thay đổi lịch, điểm hoặc thanh toán. Lịch mới vẫn cần quy trình duyệt của nhà.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: input,
          minLines: 2,
          maxLines: 5,
          maxLength: 8000,
          decoration: const InputDecoration(
            labelText: 'Bạn muốn làm gì?',
            hintText: 'Ví dụ: tối thứ Ba tôi bận từ 19 đến 21 giờ',
            border: OutlineInputBorder(),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: busy
              ? null
              : () => action(() async {
                  final value = await ref.read(aiRepositoryProvider).post(
                    widget.houseId,
                    'interpret',
                    {'text': input.text},
                  );
                  if (mounted) setState(() => interpretation = value);
                }),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Hiểu yêu cầu'),
        ),
        AiVoiceControls(
          controller: input,
          summary: interpretation?['summary']?.toString() ?? '',
          disabled: busy,
        ),
        if (interpretation != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(interpretation!['summary']?.toString() ?? ''),
                if ((interpretation!['missing_fields'] as List? ?? [])
                    .isNotEmpty)
                  Text(
                    'Cần làm rõ: ${(interpretation!['missing_fields'] as List).join(', ')}',
                  ),
                const Text('Đây là bản diễn giải, chưa áp dụng thay đổi.'),
                if (interpretation!['availability'] is Map)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AiAvailabilityReviewScreen(
                          houseId: widget.houseId,
                          candidate: interpretation!['availability'] as Map,
                        ),
                      ),
                    ),
                    child: const Text('Xem lại và xác nhận lịch bận / rảnh'),
                  ),
              ],
            ),
          ),
        if (widget.owner) ...[
          const Divider(height: 32),
          FilledButton.icon(
            onPressed:
                busy ||
                    season == null ||
                    !(season['status'] == 0 || season['status'] == 'DRAFT')
                ? null
                : () => action(() async {
                    requestId ??= const Uuid().v4();
                    final value = await ref.read(aiRepositoryProvider).post(
                      widget.houseId,
                      'schedules/propose',
                      {
                        'clientRequestId': requestId,
                        'seasonId': season['id'],
                        'kind': 'ALLOCATION',
                      },
                    );
                    if (mounted) setState(() => recommendation = value);
                  }),
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Đề xuất lịch mùa nháp'),
          ),
          if (season == null ||
              !(season['status'] == 0 || season['status'] == 'DRAFT'))
            const Text('Tạo hoặc chọn mùa nháp để đề xuất lịch.'),
        ],
        Wrap(
          spacing: 8,
          children: [
            for (final kind in [
              'REPLAN',
              'URGENT',
              if (widget.owner) 'EVOLUTION',
            ])
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AiPlanningScreen(
                            houseId: widget.houseId,
                            kind: kind,
                          ),
                        ),
                      ),
                child: Text(switch (kind) {
                  'REPLAN' => 'Sắp lại lịch',
                  'URGENT' => 'Chiến dịch khẩn cấp',
                  _ => 'Học từ mùa trước',
                }),
              ),
          ],
        ),
        if (recommendation != null) ...[
          const SizedBox(height: 16),
          Text('Trạng thái: ${recommendation!['status']}'),
          Text(result?['reason']?.toString() ?? ''),
          if (result?['metrics'] is Map)
            Text(
              'Xếp được ${(result!['metrics'] as Map)['coverage_count']} việc · Chênh Karma ${(result['metrics'] as Map)['karma_gap']}',
            ),
          for (final task in tasks)
            ListTile(
              title: Text(task['name']?.toString() ?? 'Công việc'),
              subtitle: Text(
                task['assigned_to'] == null
                    ? 'Chưa tìm được người phù hợp'
                    : '${task['assigned_to']} · ${task['start_at']}',
              ),
            ),
          if (recommendation!['status'] == 'READY')
            FilledButton(
              onPressed: busy
                  ? null
                  : () => action(() async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Áp dụng vào mùa nháp?'),
                          content: const Text(
                            'Lịch nháp sẽ được cập nhật. Sau đó mọi thành viên vẫn phải duyệt lịch.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Hủy'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Áp dụng'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !mounted) return;
                      final value = await ref
                          .read(aiRepositoryProvider)
                          .post(
                            widget.houseId,
                            'recommendations/${recommendation!['id']}/accept',
                            {},
                          );
                      if (mounted) {
                        setState(() => recommendation = value);
                        ref.invalidate(activeSeasonProvider(widget.houseId));
                      }
                    }),
              child: const Text('Áp dụng bản đã xem'),
            ),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    requestId = null;
                    recommendation = null;
                  }),
            child: const Text('Tạo đề xuất khác'),
          ),
        ],
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error!, style: const TextStyle(color: AppTheme.red)),
          ),
      ],
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings({required this.houseId, required this.owner});
  final String houseId;
  final bool owner;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> update(String path, Map<String, dynamic> body) async {
      try {
        await ref.read(aiRepositoryProvider).put(houseId, path, body);
        ref.invalidate(aiDataProvider((house: houseId, path: path)));
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (owner)
          AiDataView(
            houseId: houseId,
            path: 'settings',
            builder: (data) => Column(
              children: [
                SwitchListTile(
                  title: const Text('Bật AI cho nhà'),
                  subtitle: const Text(
                    'Các luồng thủ công vẫn hoạt động khi AI không khả dụng.',
                  ),
                  value: data['Enabled'] == true || data['enabled'] == true,
                  onChanged: (value) => update('settings', {
                    'enabled': value,
                    'chatAutoInsightsEnabled':
                        data['chat_auto_insights_enabled'] == true,
                  }),
                ),
                SwitchListTile(
                  title: const Text('Gợi ý từ tin nhắn mới'),
                  subtitle: const Text(
                    'Chỉ xử lý tin nhắn của thành viên đã bật đồng ý; kết quả riêng tư và cần xác nhận.',
                  ),
                  value: data['chat_auto_insights_enabled'] == true,
                  onChanged: data['enabled'] == true
                      ? (value) => update('settings', {
                          'enabled': true,
                          'chatAutoInsightsEnabled': value,
                        })
                      : null,
                ),
              ],
            ),
          ),
        AiDataView(
          houseId: houseId,
          path: 'me/consent',
          builder: (data) => SwitchListTile(
            title: const Text('Cho phép phân tích tin nhắn của tôi'),
            subtitle: const Text(
              'Cho phép phân tích khi bạn yêu cầu; tin nhắn mới có thể được xử lý nếu nhà bật gợi ý tự động. Thu hồi sẽ xóa kết quả dẫn xuất.',
            ),
            value:
                data['ChatAnalysisEnabled'] == true ||
                data['chatAnalysisEnabled'] == true ||
                data['chat_analysis_enabled'] == true,
            onChanged: (value) =>
                update('me/consent', {'chatAnalysisEnabled': value}),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Đóng góp được ghi nhận theo sự kiện nghiệp vụ. Số lần nhận bounty không tạo thêm nghĩa vụ. Chưa có timer hoặc model thời lượng.',
        ),
        ListTile(
          leading: const Icon(Icons.event_available),
          title: const Text('Xác nhận lịch bận / rảnh theo ngày'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  AiAvailabilityReviewScreen(houseId: houseId),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.insights_outlined),
          title: const Text('Đánh giá trách nhiệm của tôi'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AiRiskInsightsScreen(houseId: houseId),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: const Text('Gợi ý riêng từ tin nhắn'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  AiInsightsScreen(houseId: houseId, chat: true),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.volunteer_activism_outlined),
          title: const Text('Bounty phù hợp'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AiInsightsScreen(houseId: houseId),
            ),
          ),
        ),
      ],
    );
  }
}
