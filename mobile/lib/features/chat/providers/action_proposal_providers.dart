import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';
import 'package:chore_wars/features/chat/data/services/action_proposal_service.dart';

final actionProposalServiceProvider = Provider<ActionProposalService>((ref) {
  return ActionProposalService(ref.watch(dioProvider));
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

  Future<void> respondProposal({
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
  }
}

final actionProposalProvider = NotifierProvider.family<
    ActionProposalNotifier,
    AsyncValue<List<ActionProposalModel>>,
    String>(
  ActionProposalNotifier.new,
);
