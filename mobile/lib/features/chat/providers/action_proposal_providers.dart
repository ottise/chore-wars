import '../../notifications/presentation/providers/notification_providers.dart';

import 'dart:async';

import 'package:chore_wars/core/storage/session_provider.dart';

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
      ref.watch(sessionEpochProvider);
      final room = await ref.watch(
        assistantRequestRoomProvider(houseId).future,
      );
      if (!ref.mounted) return null;
      final proposals =
          ref.watch(actionProposalProvider(room)).asData?.value ?? [];
      final now = DateTime.now();
      for (final proposal in proposals) {
        if (proposal.type == ProposalType.urgentEvent &&
            proposal.status == ProposalStatus.approved &&
            proposal.expiresAt != null &&
            proposal.expiresAt!.isAfter(now)) {
          final expiryTimer = Timer(
            proposal.expiresAt!.difference(now),
            ref.invalidateSelf,
          );
          ref.onDispose(expiryTimer.cancel);
          return proposal;
        }
      }
      return null;
    });

class ActionProposalNotifier
    extends Notifier<AsyncValue<List<ActionProposalModel>>> {
  final String roomId;
  int _generation = 0;
  int _stateRevision = 0;
  bool _fetching = false;
  ActionProposalNotifier(this.roomId);

  @override
  AsyncValue<List<ActionProposalModel>> build() {
    ref.watch(sessionEpochProvider);
    final generation = ++_generation;
    Future.microtask(() {
      if (ref.mounted && generation == _generation) loadProposals();
    });
    return const AsyncValue.loading();
  }

  Future<void> loadProposals() async {
    if (_fetching) return;
    _fetching = true;
    final generation = _generation;
    final revision = _stateRevision;
    try {
      if (!state.hasValue) state = const AsyncValue.loading();
      final service = ref.read(actionProposalServiceProvider);
      final proposals = await service.getActiveProposals(roomId);
      if (ref.mounted &&
          generation == _generation &&
          revision == _stateRevision) {
        state = AsyncValue.data(proposals);
      }
    } catch (e, st) {
      if (ref.mounted &&
          generation == _generation &&
          revision == _stateRevision) {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _fetching = false;
    }
  }

  void addProposal(ActionProposalModel proposal) {
    _stateRevision++;
    final proposals = state.asData?.value ?? <ActionProposalModel>[];
    final index = proposals.indexWhere((p) => p.id == proposal.id);
    if (index != -1) {
      final updated = List<ActionProposalModel>.from(proposals);
      updated[index] = proposal;
      state = AsyncValue.data(updated);
    } else {
      state = AsyncValue.data([proposal, ...proposals]);
    }
  }

  void updateProposal(ActionProposalModel proposal) {
    addProposal(proposal);
  }

  Future<ActionProposalModel> respondProposal({
    required String proposalId,
    required ProposalConfirmationStatus status,
    String? reason,
  }) async {
    final generation = _generation;
    _stateRevision++;
    final service = ref.read(actionProposalServiceProvider);
    final updated = await service.respondProposal(
      proposalId: proposalId,
      status: status,
      reason: reason,
    );
    if (ref.mounted && generation == _generation) updateProposal(updated);
    return updated;
  }
}

final actionProposalProvider = NotifierProvider.autoDispose
    .family<
      ActionProposalNotifier,
      AsyncValue<List<ActionProposalModel>>,
      String
    >(ActionProposalNotifier.new);

final assistantRequestRoomProvider = FutureProvider.autoDispose
    .family<String, String>((ref, houseId) async {
      ref.watch(sessionEpochProvider);
      final room = await ref
          .watch(chatRepositoryProvider)
          .getHouseRoom(houseId);
      if (!ref.mounted) return room.id;
      final timer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (ref.mounted &&
            !ref.read(actionProposalProvider(room.id)).hasError) {
          ref.read(actionProposalProvider(room.id).notifier).loadProposals();
        }
      });
      ref.onDispose(timer.cancel);
      return room.id;
    }, retry: (_, _) => null);

final assistantInboxProvider = FutureProvider.autoDispose
    .family<List<ActionProposalModel>, String>((ref, houseId) async {
      ref.watch(sessionEpochProvider);
      ref.watch(
        notificationNotifierProvider.select((s) => s.latestArrival?.id),
      );
      final proposals = await ref
          .watch(actionProposalServiceProvider)
          .getAssistantInbox(houseId);
      if (ref.mounted) {
        final timer = Timer(const Duration(seconds: 10), ref.invalidateSelf);
        ref.onDispose(timer.cancel);
      }
      return proposals;
    }, retry: (_, _) => null);
