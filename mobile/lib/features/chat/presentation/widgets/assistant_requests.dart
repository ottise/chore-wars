import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/session_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/action_proposal_model.dart';
import '../../providers/action_proposal_providers.dart';
import '../../providers/chat_providers.dart';
import 'interactive_action_card.dart';

final assistantRequestRoomProvider = FutureProvider.autoDispose
    .family<String, String>((ref, houseId) async {
      ref.watch(sessionEpochProvider);
      final room = await ref
          .watch(chatRepositoryProvider)
          .getHouseRoom(houseId);
      if (!ref.mounted) return room.id;
      final timer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (ref.mounted) {
          ref.read(actionProposalProvider(room.id).notifier).loadProposals();
        }
      });
      ref.onDispose(timer.cancel);
      return room.id;
    });

class AssistantRequests extends ConsumerWidget {
  const AssistantRequests({required this.houseId, super.key});
  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).asData?.value;
    if (user == null) return const SizedBox.shrink();
    final room = ref.watch(assistantRequestRoomProvider(houseId)).asData?.value;
    if (room == null) return const SizedBox.shrink();
    final requests =
        (ref.watch(actionProposalProvider(room)).asData?.value ?? [])
            .where(
              (proposal) =>
                  proposal.type == ProposalType.urgentEvent &&
                  proposal.status == ProposalStatus.pending &&
                  (proposal.isTarget(user.id) || proposal.creatorId == user.id),
            )
            .toList();
    if (requests.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .35,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Task requests',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          for (final proposal in requests)
            InteractiveActionCard(proposal: proposal, currentUserId: user.id),
        ],
      ),
    );
  }
}
