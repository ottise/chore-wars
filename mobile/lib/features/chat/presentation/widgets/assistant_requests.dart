import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/action_proposal_model.dart';
import '../../providers/action_proposal_providers.dart';
import 'interactive_action_card.dart';

export '../../providers/action_proposal_providers.dart'
    show assistantRequestRoomProvider;

class AssistantRequests extends ConsumerWidget {
  const AssistantRequests({
    required this.houseId,
    this.urgentOnly = false,
    this.inline = false,
    super.key,
  });
  final String houseId;
  final bool urgentOnly;
  final bool inline;

  Widget _error(Object error, VoidCallback retry) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(apiErrorMessage(error)),
        TextButton(onPressed: retry, child: const Text('Retry task requests')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider);
    final userId =
        ref.watch(userProfileProvider).asData?.value.id ??
        (session is AuthAuthenticated ? session.user.userId : null);
    if (userId == null) return const SizedBox.shrink();
    final room = ref.watch(assistantRequestRoomProvider(houseId));
    return room.when(
      loading: () => inline
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            )
          : const SizedBox.shrink(),
      error: (error, _) => inline
          ? _error(
              error,
              () => ref.invalidate(assistantRequestRoomProvider(houseId)),
            )
          : const SizedBox.shrink(),
      data: (roomId) {
        final state = ref.watch(actionProposalProvider(roomId));
        return state.when(
          loading: () => inline
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                )
              : const SizedBox.shrink(),
          error: (error, _) => inline
              ? _error(
                  error,
                  () => ref
                      .read(actionProposalProvider(roomId).notifier)
                      .loadProposals(),
                )
              : const SizedBox.shrink(),
          data: (proposals) {
            final now = DateTime.now();
            final requests = proposals
                .where(
                  (proposal) =>
                      (proposal.type == ProposalType.urgentEvent ||
                          (!urgentOnly &&
                              proposal.type == ProposalType.supplyPurchase)) &&
                      proposal.status == ProposalStatus.pending &&
                      (proposal.expiresAt == null ||
                          proposal.expiresAt!.isAfter(now)) &&
                      (proposal.isTarget(userId) ||
                          proposal.creatorId == userId),
                )
                .toList();
            if (requests.isEmpty) {
              return const SizedBox.shrink();
            }
            final children = <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  urgentOnly ? 'Task requests to confirm' : 'Task requests',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final proposal in requests)
                InteractiveActionCard(
                  key: ValueKey(proposal.id),
                  proposal: proposal,
                  currentUserId: userId,
                ),
            ];
            if (inline) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .35,
              ),
              child: ListView(shrinkWrap: true, children: children),
            );
          },
        );
      },
    );
  }
}
