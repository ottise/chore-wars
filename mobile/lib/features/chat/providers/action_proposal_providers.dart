import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';
import 'package:chore_wars/features/chat/data/services/action_proposal_service.dart';
import 'package:chore_wars/features/chat/providers/chat_providers.dart';

final actionProposalServiceProvider = Provider<ActionProposalService>((ref) {
  return ActionProposalService(ref.watch(dioProvider));
});

final activeUrgentEventForHouseProvider = FutureProvider.autoDispose
    .family<ActionProposalModel?, String>((ref, houseId) async {
  final refreshTimer = Timer(
    const Duration(seconds: 3),
    ref.invalidateSelf,
  );
  ref.onDispose(refreshTimer.cancel);
  final room = await ref.watch(chatRepositoryProvider).getHouseRoom(houseId);
  final proposals = await ref
      .watch(actionProposalServiceProvider)
      .getActiveProposals(room.id);
  final now = DateTime.now();
  for (final proposal in proposals) {
    if (proposal.type == ProposalType.urgentEvent &&
        proposal.status == ProposalStatus.approved &&
        proposal.expiresAt != null &&
        proposal.expiresAt!.isAfter(now)) {
      return proposal;
    }
  }
  return null;
});

class ActionProposalNotifier
    extends Notifier<AsyncValue<List<ActionProposalModel>>> {
  final String roomId;
  ActionProposalNotifier(this.roomId);

  @override
  AsyncValue<List<ActionProposalModel>> build() {
    Future.microtask(() => loadProposals());
    return const AsyncValue.loading();
  }

  Future<void> loadProposals() async {
    try {
      final service = ref.read(actionProposalServiceProvider);
      final proposals = await service.getActiveProposals(roomId);
      state = AsyncValue.data(proposals);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void addProposal(ActionProposalModel proposal) {
    state.whenData((proposals) {
      final index = proposals.indexWhere((p) => p.id == proposal.id);
      if (index != -1) {
        final updated = List<ActionProposalModel>.from(proposals);
        updated[index] = proposal;
        state = AsyncValue.data(updated);
      } else {
        state = AsyncValue.data([proposal, ...proposals]);
      }
    });
  }

  void updateProposal(ActionProposalModel proposal) {
    state.whenData((proposals) {
      final updated =
          proposals.map((p) => p.id == proposal.id ? proposal : p).toList();
      state = AsyncValue.data(updated);
    });
  }

  Future<ActionProposalModel> respondProposal({
    required String proposalId,
    required ProposalConfirmationStatus status,
    String? reason,
  }) async {
    final service = ref.read(actionProposalServiceProvider);
    final updated = await service.respondProposal(
      proposalId: proposalId,
      status: status,
      reason: reason,
    );
    updateProposal(updated);
    return updated;
  }
}

final actionProposalProvider = NotifierProvider.family<
    ActionProposalNotifier,
    AsyncValue<List<ActionProposalModel>>,
    String>(
  ActionProposalNotifier.new,
);
