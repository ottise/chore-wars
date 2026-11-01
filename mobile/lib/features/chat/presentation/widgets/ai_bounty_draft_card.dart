import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/vietnam_time.dart';

class AiBountyDraftCard extends StatelessWidget {
  const AiBountyDraftCard({
    required this.houseId,
    required this.candidate,
    required this.onRetry,
    super.key,
  });
  final String houseId;
  final Map<String, dynamic> candidate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final amount = candidate['amount'];
    final due = DateTime.tryParse(candidate['due_at']?.toString() ?? '');
    final postedId = candidate['posted_id']?.toString();
    final posting = candidate['posting'] == true;
    final error = candidate['posting_error']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              postedId != null
                  ? 'Bounty posted successfully.'
                  : posting
                  ? 'Posting bounty...'
                  : 'Bounty was not posted.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(candidate['chore_name']?.toString() ?? 'Chore'),
            if (amount is num)
              Text(
                '${NumberFormat.decimalPattern('en_US').format(amount)} VND',
              ),
            if (due != null)
              Text(
                'Chore deadline (Vietnam): ${DateFormat('dd/MM/yyyy HH:mm').format(vietnamTime(due))}',
              ),
            if (posting) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: posting ? null : onRetry,
                child: const Text('Retry posting bounty'),
              ),
            ],
            if (postedId != null)
              TextButton(
                onPressed: () => context.push(
                  '/bounties/${Uri.encodeComponent(postedId)}?houseId=${Uri.encodeComponent(houseId)}',
                ),
                child: const Text('View bounty'),
              ),
          ],
        ),
      ),
    );
  }
}
