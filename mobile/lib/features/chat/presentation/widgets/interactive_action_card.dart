import 'package:flutter/material.dart';

import '../../data/models/action_proposal_model.dart';

/// Existing proposal data remains visible while proposal execution is deferred.
class InteractiveActionCard extends StatelessWidget {
  final ActionProposalModel proposal;
  final String currentUserId;
  const InteractiveActionCard({
    super.key,
    required this.proposal,
    required this.currentUserId,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(proposal.title, style: Theme.of(context).textTheme.titleMedium),
          if (proposal.description.isNotEmpty) Text(proposal.description),
          const SizedBox(height: 8),
          const Text(
            'Proposal actions are currently unavailable. Season approvals use Review schedule.',
          ),
        ],
      ),
    ),
  );
}
