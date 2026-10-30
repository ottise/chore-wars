import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../data/models/action_proposal_model.dart';
import '../../providers/action_proposal_providers.dart';
import 'interactive_action_card.dart';

class AssistantInbox extends ConsumerStatefulWidget {
  const AssistantInbox({required this.houseId, super.key});
  final String houseId;
  @override
  ConsumerState<AssistantInbox> createState() => _AssistantInboxState();
}

class _AssistantInboxState extends ConsumerState<AssistantInbox> {
  final _attemptedReads = <String>{};
  Object? _readError;

  void _markRead(List<ActionProposalModel> proposals) {
    final ids = proposals.map((p) => p.id).toSet();
    final notices = ref
        .read(notificationNotifierProvider)
        .notifications
        .where(
          (n) =>
              n.houseId == widget.houseId &&
              n.isTaskRequest &&
              !n.isRead &&
              ids.contains(n.targetId) &&
              !_attemptedReads.contains(n.id),
        )
        .toList();
    if (notices.isEmpty) return;
    _attemptedReads.addAll(notices.map((n) => n.id));
    Future.microtask(() async {
      for (final notice in notices) {
        if (!mounted) return;
        try {
          await ref
              .read(notificationNotifierProvider.notifier)
              .markAsRead(notice.id);
        } catch (e) {
          if (mounted) setState(() => _readError = e);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationNotifierProvider);
    final auth = ref.watch(authStateProvider);
    final user =
        ref.watch(userProfileProvider).asData?.value.id ??
        (auth is AuthAuthenticated ? auth.user.userId : null);
    if (user == null) return const SizedBox.shrink();
    final inbox = ref.watch(assistantInboxProvider(widget.houseId));
    return inbox.when(
      skipLoadingOnRefresh: true,
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Column(
        children: [
          Text(apiErrorMessage(error)),
          TextButton(
            onPressed: () =>
                ref.invalidate(assistantInboxProvider(widget.houseId)),
            child: const Text('Retry AI requests'),
          ),
        ],
      ),
      data: (proposals) {
        final mine = proposals
            .where((p) => p.creatorId == user || p.isTarget(user))
            .toList();
        _markRead(mine);
        if (mine.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Your assistant · Requests',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (_readError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(apiErrorMessage(_readError!)),
                    TextButton(
                      onPressed: () => setState(() {
                        _attemptedReads.clear();
                        _readError = null;
                      }),
                      child: const Text('Retry marking requests read'),
                    ),
                  ],
                ),
              ),
            for (final proposal in mine) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '${proposal.creatorId == user ? 'You' : proposal.creatorName ?? 'Household member'} → Your assistant · ${DateFormat('dd/MM HH:mm').format(vietnamTime(proposal.createdAt))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              InteractiveActionCard(
                key: ValueKey('inbox-${proposal.id}'),
                proposal: proposal,
                currentUserId: user,
              ),
            ],
          ],
        );
      },
    );
  }
}
