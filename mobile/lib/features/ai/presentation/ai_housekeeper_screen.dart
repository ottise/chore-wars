import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'ai_setup_view.dart';

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
        appBar: AppBar(title: const Text('AI Housekeeper')),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(houseDetailProvider(houseId)),
        ),
      ),
      data: (value) {
        final owner = value.myRole == HouseRole.owner;
        final key = (house: houseId, path: 'settings');
        return ref
            .watch(aiDataProvider(key))
            .when(
              loading: () => const Scaffold(body: LoadingView()),
              error: (error, _) => Scaffold(
                appBar: AppBar(title: const Text('Assistant')),
                body: ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(aiDataProvider(key)),
                ),
              ),
              data: (settings) {
                if (settings['configured'] == false ||
                    settings['enabled'] != true) {
                  return AiSetupView(
                    houseId: houseId,
                    owner: owner,
                    settings: settings,
                  );
                }
                return DefaultTabController(
                  length: owner ? 4 : 3,
                  child: Scaffold(
                    appBar: AppBar(
                      title: const Text('AI Housekeeper'),
                      bottom: TabBar(
                        isScrollable: true,
                        tabs: [
                          const Tab(text: 'Contributions'),
                          if (owner) const Tab(text: 'Evaluation'),
                          const Tab(text: 'Suggestions'),
                          const Tab(text: 'Settings'),
                        ],
                      ),
                    ),
                    body: TabBarView(
                      children: [
                        _Profiles(
                          key: ValueKey((
                            houseId,
                            ref.watch(sessionEpochProvider),
                          )),
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
              decoration: const InputDecoration(labelText: 'Time Range'),
              items: [
                for (final entry in {
                  'all-time': 'All Time',
                  '30d': 'Last 30 Days',
                  '90d': 'Last 90 Days',
                  if (seasons.isNotEmpty) 'season': 'By Season',
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
                decoration: const InputDecoration(labelText: 'Season'),
                items: [
                  for (final item in seasons)
                    DropdownMenuItem(
                      value: item['id'].toString(),
                      child: Text(item['name']?.toString() ?? 'Season'),
                    ),
                ],
                onChanged: (value) => setState(() => seasonId = value),
              ),
            const SizedBox(height: 16),
            Text(
              'Recorded Contributions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Standard workload and responsibility history explain contributions. They do not assess personality or create extra obligations.',
            ),
            if (data['telemetry_complete'] == false)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Data is syncing. There is not enough information to draw conclusions.',
                  style: TextStyle(color: AppTheme.orange),
                ),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No activities with sufficient evidence yet. Complete chores through the normal workflow to begin recording contributions.',
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
                        names[raw['member_id']] ?? 'Member',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${raw['completed_count']} chores actually completed · ${raw['standard_minutes']} standard effort minutes',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bounty: accepted ${raw['bounty_occurrence_count']} chores, self-completed ${raw['bounty_self_completed']}, completed by others ${raw['bounty_other_completed']}.',
                      ),
                      Text(
                        'Not yet due: ${raw['bounty_pending']} · Open overdue: ${raw['bounty_overdue_open']}',
                      ),
                      ExpansionTile(
                        title: const Text('Responsibilities & Points'),
                        children: [
                          ListTile(
                            title: Text(
                              'Responsibilities accepted: ${raw['responsibility_count'] ?? 0} episodes',
                            ),
                            subtitle: Text(
                              'Source: ${raw['responsibility_source_counts'] ?? {}}\nCompletions by source: ${raw['completion_source_counts'] ?? {}}',
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'On time: ${raw['on_time_episode_count'] ?? 0} / ${raw['on_time_episode_denominator'] ?? 0} eligible outcome episodes',
                            ),
                            subtitle: Text(
                              'Pending: ${raw['pending_episode_count'] ?? 0} · Excluded/censored: ${raw['censored_episode_count'] ?? 0}',
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'Adjustment requests: ${raw['adjustment_request_status_counts'] ?? {}}',
                            ),
                            subtitle: const Text(
                              'Requests, approvals and rejections are reported separately; motives are not inferred.',
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'Ranked first ${raw['season_wins'] ?? 0} · Ranked last ${raw['season_bottoms'] ?? 0} / ${raw['ranked_seasons'] ?? 0} seasons',
                            ),
                            subtitle: Text(
                              'Karma breakdown: ${raw['ledger_breakdown'] ?? {}}',
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'Posted ${raw['bounty_posted_count'] ?? 0} bounty',
                            ),
                            subtitle: Text(
                              'Posted reward amounts: ${(raw['bounty_posted_amounts'] as List? ?? []).take(20).join(', ')}',
                            ),
                          ),
                        ],
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          '${(raw['evidence_ids'] as List? ?? []).length} activity evidence',
                        ),
                        children: [
                          for (final id
                              in (raw['evidence_ids'] as List? ?? []).take(20))
                            ListTile(
                              dense: true,
                              title: const Text('Open Activity Evidence'),
                              subtitle: Text(id.toString()),
                              trailing: const Icon(
                                Icons.chevron_right_outlined,
                              ),
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
  @override
  void initState() {
    super.initState();
    input.addListener(() {
      if (mounted) setState(() {});
    });
  }

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
          'Preview Before Deciding',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'AI does not automatically change schedules, points or payments. New schedules still require household approval.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: input,
          minLines: 2,
          maxLines: 5,
          maxLength: 8000,
          decoration: const InputDecoration(
            labelText: 'What would you like to do?',
            hintText: 'Example: I am busy on Tuesday from 7 PM to 9 PM',
            border: OutlineInputBorder(),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: busy || input.text.trim().isEmpty
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
          label: const Text('Interpret Request'),
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
                    'Needs clarification: ${(interpretation!['missing_fields'] as List).join(', ')}',
                  ),
                const Text(
                  'This is an interpretation; no changes have been applied.',
                ),
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
                    child: const Text('Review & Confirm Availability'),
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
            label: const Text('Suggest Draft Schedule'),
          ),
          if (season == null ||
              !(season['status'] == 0 || season['status'] == 'DRAFT'))
            const Text(
              'Create or choose a draft season to request a schedule.',
            ),
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
                  'REPLAN' => 'Replan Schedule',
                  'URGENT' => 'Urgent Campaign',
                  _ => 'Learn from Previous Seasons',
                }),
              ),
          ],
        ),
        if (recommendation != null) ...[
          const SizedBox(height: 16),
          Text('Status: ${recommendation!['status']}'),
          Text(result?['reason']?.toString() ?? ''),
          if (result?['metrics'] is Map)
            Text(
              'Scheduled ${(result!['metrics'] as Map)['coverage_count']} chores · Karma gap ${(result['metrics'] as Map)['karma_gap']}',
            ),
          for (final task in tasks)
            ListTile(
              title: Text(task['name']?.toString() ?? 'Chore'),
              subtitle: Text(
                task['assigned_to'] == null
                    ? 'No suitable member found'
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
                          title: const Text('Apply to Draft Season?'),
                          content: const Text(
                            'The draft schedule will be updated. Every member must still approve it.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Apply'),
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
              child: const Text('Apply Reviewed Schedule'),
            ),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    requestId = null;
                    recommendation = null;
                  }),
            child: const Text('Create Another Suggestion'),
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
                  title: const Text('Enable Household AI'),
                  subtitle: const Text(
                    'Manual workflows remain available when AI is unavailable.',
                  ),
                  value: data['Enabled'] == true || data['enabled'] == true,
                  onChanged: (value) => update('settings', {
                    'enabled': value,
                    'chatAutoInsightsEnabled':
                        data['chat_auto_insights_enabled'] == true,
                  }),
                ),
                SwitchListTile(
                  title: const Text('Suggestions from New Messages'),
                  subtitle: const Text(
                    'Only messages from consenting members are processed; results are private and require confirmation.',
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
            title: const Text('Allow Analysis of My Messages'),
            subtitle: const Text(
              'Allow analysis when requested; new messages may be processed if household suggestions are enabled. Revoking consent removes derived results.',
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
          'Contributions are recorded from application events. Bounty acceptances do not create extra obligations. No timer or duration model is used.',
        ),
        ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: const Text('Confirm Daily Availability'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  AiAvailabilityReviewScreen(houseId: houseId),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.insights_outlined),
          title: const Text('Evaluate My Responsibilities'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AiRiskInsightsScreen(houseId: houseId),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: const Text('Private Chat Insights'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  AiInsightsScreen(houseId: houseId, chat: true),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.volunteer_activism_outlined),
          title: const Text('Matching Bounties'),
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
