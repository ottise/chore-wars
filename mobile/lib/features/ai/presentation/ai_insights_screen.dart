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
        title: Text(chat ? 'Private Chat Insights' : 'Bounties for You'),
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
                      ? 'Only you can see insights from your messages. They require confirmation and do not change availability or responsibility.'
                      : 'Optional suggestions based on availability, declared preferences and experience. Accepting more bounties does not increase required chores.',
                ),
                if ((data['items'] as List? ?? []).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No eligible suggestions yet.'),
                  ),
                for (final item in data['items'] as List? ?? [])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: chat
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status: ${item['status']}'),
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
                                  Text('Needs clarification: $missing'),
                                Text('Source message: ${item['message_id']}'),
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
                                      'Review & Confirm Availability',
                                    ),
                                  ),
                                const Text(
                                  'To confirm a change, edit your availability or create a proposal and review it with affected members.',
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name']?.toString() ?? 'Chore',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  '${NumberFormat.currency(locale: 'en_US', symbol: '₫', decimalDigits: 0).format(item['amount'])} · ${item['declared_preference']}',
                                ),
                                Text(
                                  'Available from ${item['possible_start']}',
                                ),
                                Text(
                                  'Reason: ${item['reason']} · ${item['historical_completions_capped']} prior completions (capped at 20)',
                                ),
                                TextButton(
                                  onPressed: () => context.push(
                                    '/bounties/${item['bounty_id']}?houseId=$houseId',
                                  ),
                                  child: const Text('View Bounty & Decide'),
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
