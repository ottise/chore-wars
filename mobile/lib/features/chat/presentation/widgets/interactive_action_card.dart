import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/core/utils/api_error_message.dart';
import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';
import 'package:chore_wars/features/chat/providers/action_proposal_providers.dart';

class InteractiveActionCard extends ConsumerStatefulWidget {
  final ActionProposalModel proposal;
  final String currentUserId;

  const InteractiveActionCard({
    required this.proposal,
    required this.currentUserId,
    super.key,
  });

  @override
  ConsumerState<InteractiveActionCard> createState() =>
      _InteractiveActionCardState();
}

class _InteractiveActionCardState extends ConsumerState<InteractiveActionCard> {
  bool _isResponding = false;

  IconData _getTypeIcon(ProposalType type) {
    switch (type) {
      case ProposalType.choreSwap:
        return Icons.swap_horiz_outlined;
      case ProposalType.urgentEvent:
        return Icons.bolt_outlined;
      case ProposalType.seasonApproval:
        return Icons.assignment_turned_in_outlined;
      case ProposalType.scheduleReplan:
        return Icons.calendar_month_outlined;
    }
  }

  Color _getTypeColor(ProposalType type) {
    switch (type) {
      case ProposalType.choreSwap:
        return AppTheme.purple;
      case ProposalType.urgentEvent:
        return AppTheme.orange;
      case ProposalType.seasonApproval:
        return AppTheme.purple;
      case ProposalType.scheduleReplan:
        return AppTheme.purple;
    }
  }

  String _getTypeLabel(ProposalType type) {
    switch (type) {
      case ProposalType.choreSwap:
        return 'CHORE SWAP REQUEST';
      case ProposalType.urgentEvent:
        return 'URGENT TASKS';
      case ProposalType.seasonApproval:
        return 'SEASON APPROVAL';
      case ProposalType.scheduleReplan:
        return 'Schedule Change Proposal';
    }
  }

  Future<void> _respond(
    ProposalConfirmationStatus status, {
    String? reason,
  }) async {
    setState(() => _isResponding = true);
    try {
      final updated = await ref
          .read(actionProposalProvider(widget.proposal.roomId).notifier)
          .respondProposal(
            proposalId: widget.proposal.id,
            status: status,
            reason: reason,
          );
      if (mounted &&
          updated.type == ProposalType.urgentEvent &&
          updated.status == ProposalStatus.approved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Campaign activated! The countdown has started.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isResponding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposal = widget.proposal;
    if (proposal.type == ProposalType.seasonApproval) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(proposal.title),
              const Text(
                'Proposal actions are currently unavailable. Season approvals use Review schedule.',
              ),
            ],
          ),
        ),
      );
    }
    final isTarget = proposal.isTarget(widget.currentUserId);
    final hasResponded = proposal.hasUserResponded(widget.currentUserId);
    final canRespond =
        !proposal.isCompleted &&
        isTarget &&
        !hasResponded &&
        (proposal.expiresAt == null ||
            proposal.expiresAt!.isAfter(DateTime.now()));

    Color cardBg;
    if (proposal.status == ProposalStatus.approved) {
      cardBg = AppTheme.successContainer;
    } else if (proposal.status == ProposalStatus.rejected) {
      cardBg = AppTheme.errorContainer;
    } else {
      cardBg = Theme.of(context).colorScheme.surfaceContainerHighest;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: proposal.status == ProposalStatus.approved
              ? AppTheme.green.withValues(alpha: 0.5)
              : (proposal.status == ProposalStatus.rejected
                    ? AppTheme.red.withValues(alpha: 0.5)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Type + Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getTypeColor(proposal.type).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTypeIcon(proposal.type),
                  color: _getTypeColor(proposal.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getTypeLabel(proposal.type),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: _getTypeColor(proposal.type),
                  ),
                ),
              ),
              if (proposal.status == ProposalStatus.approved)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outlined,
                      color: AppTheme.green,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Approved',
                      style: TextStyle(
                        color: AppTheme.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else if (proposal.status == ProposalStatus.rejected)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel_outlined, color: AppTheme.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Rejected',
                      style: TextStyle(
                        color: AppTheme.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.yellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        color: AppTheme.orange,
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Awaiting Approval',
                        style: TextStyle(
                          color: AppTheme.orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            proposal.title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (proposal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              proposal.description,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.muted),
            ),
          ],
          if (proposal.type == ProposalType.urgentEvent)
            _buildUrgentEventDetails(context, proposal),
          if (proposal.type == ProposalType.scheduleReplan)
            _buildReplanDetails(proposal),
          const SizedBox(height: 12),

          // Confirmations list
          if (proposal.confirmations.isNotEmpty) ...[
            Text(
              'Approval Progress (${proposal.confirmations.where((c) => c.status == ProposalConfirmationStatus.confirmed).length}/${proposal.confirmations.length}):',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: proposal.confirmations.map((conf) {
                final isMe = conf.targetUserId == widget.currentUserId;
                Color statusColor;
                IconData statusIcon;
                String statusLabel;

                switch (conf.status) {
                  case ProposalConfirmationStatus.confirmed:
                    statusColor = AppTheme.green;
                    statusIcon = Icons.check_circle_outlined;
                    statusLabel = 'Approve';
                    break;
                  case ProposalConfirmationStatus.rejected:
                    statusColor = AppTheme.red;
                    statusIcon = Icons.cancel_outlined;
                    statusLabel = 'Reject';
                    break;
                  case ProposalConfirmationStatus.pending:
                    statusColor = AppTheme.orange;
                    statusIcon = Icons.hourglass_top_outlined;
                    statusLabel = 'Pending';
                    break;
                }

                return Chip(
                  avatar: Icon(statusIcon, color: statusColor, size: 16),
                  label: Text(
                    isMe ? 'You ($statusLabel)' : statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons for target user
          if (canRespond) ...[
            if (_isResponding)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (proposal.type == ProposalType.urgentEvent)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _respond(ProposalConfirmationStatus.confirmed),
                      icon: const Icon(Icons.bolt_outlined, size: 18),
                      label: const Text('Tham gia ngay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _respond(
                        ProposalConfirmationStatus.rejected,
                        reason: 'Busy, unable to participate.',
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Unavailable'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.red,
                        side: const BorderSide(color: AppTheme.red),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _respond(ProposalConfirmationStatus.confirmed),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _respond(ProposalConfirmationStatus.rejected),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.red,
                        side: const BorderSide(color: AppTheme.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ] else if (isTarget && hasResponded) ...[
            Text(
              proposal.hasUserConfirmed(widget.currentUserId)
                  ? '✅ You have approved this request.'
                  : '❌ You have rejected this request.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: proposal.hasUserConfirmed(widget.currentUserId)
                    ? AppTheme.green
                    : AppTheme.red,
              ),
            ),
          ] else if (!isTarget) ...[
            Text(
              '👁️ This request is intended for another member.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppTheme.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplanDetails(ActionProposalModel proposal) {
    try {
      final payload = jsonDecode(proposal.payloadJson) as Map<String, dynamic>;
      final changes = (payload['Changes'] ?? payload['changes']) as List? ?? [];
      final availability =
          (payload['AvailabilityChanges'] ?? payload['availabilityChanges'])
              as List? ??
          [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The owner and every affected member must agree. If anyone rejects, the schedule stays unchanged.',
          ),
          for (final change in availability)
            Text(
              'New availability for ${change['UserId'] ?? change['userId']} day ${change['LocalDate'] ?? change['localDate']}: ${change['Slots'] ?? change['slots']}',
            ),
          for (final change in changes)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${change['Name'] ?? change['name']}\n${change['PreviousUserId'] ?? change['previousUserId']} → ${change['AssignedUserId'] ?? change['assignedUserId']}\n${change['PlannedStartAt'] ?? change['plannedStartAt']}',
              ),
            ),
        ],
      );
    } on FormatException {
      return const Text('Unable to load details. Refresh before approving.');
    }
  }

  Widget _buildUrgentEventDetails(
    BuildContext context,
    ActionProposalModel proposal,
  ) {
    try {
      final payload = jsonDecode(proposal.payloadJson) as Map<String, dynamic>;
      final deadline = payload['DeadlineMinutes'] ?? payload['deadlineMinutes'];
      final chores =
          (payload['Chores'] ?? payload['chores']) as List<dynamic>? ??
          const [];
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deadline: $deadline minutes after everyone agrees',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...chores.map((raw) {
              final chore = Map<String, dynamic>.from(raw as Map);
              return Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '• ${chore['Name'] ?? chore['name']} (+${chore['KarmaPoints'] ?? chore['karmaPoints']} Karma)\nStart +${chore['PlannedOffsetMinutes'] ?? chore['plannedOffsetMinutes'] ?? 0} minutes · Dependencies: ${chore['DependsOn'] ?? chore['dependsOn'] ?? []} · Resources: ${chore['Resources'] ?? chore['resources'] ?? []}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
