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
  ConsumerState<InteractiveActionCard> createState() => _InteractiveActionCardState();
}

class _InteractiveActionCardState extends ConsumerState<InteractiveActionCard> {
  bool _isResponding = false;

  IconData _getTypeIcon(ProposalType type) {
    switch (type) {
      case ProposalType.choreSwap:
        return Icons.swap_horiz_rounded;
      case ProposalType.urgentEvent:
        return Icons.bolt_rounded;
      case ProposalType.seasonApproval:
        return Icons.assignment_turned_in_rounded;
    }
  }

  Color _getTypeColor(ProposalType type) {
    switch (type) {
      case ProposalType.choreSwap:
        return Colors.orange;
      case ProposalType.urgentEvent:
        return Colors.deepOrange;
      case ProposalType.seasonApproval:
        return Colors.blue;
    }
  }

  String _getTypeLabel(ProposalType type) {
    switch (type) {
      case ProposalType.choreSwap:
        return 'YÊU CẦU ĐỔI VIỆC NHÀ';
      case ProposalType.urgentEvent:
        return 'NHIỆM VỤ KHẨN CẤP';
      case ProposalType.seasonApproval:
        return 'PHÊ DUYỆT MÙA GIẢI';
    }
  }

  Future<void> _respond(ProposalConfirmationStatus status, {String? reason}) async {
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
            content: Text('🎉 Chiến dịch đã kích hoạt! Đồng hồ bắt đầu đếm ngược.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
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
    final isTarget = proposal.isTarget(widget.currentUserId);
    final hasResponded = proposal.hasUserResponded(widget.currentUserId);
    final canRespond = !proposal.isCompleted && isTarget && !hasResponded;

    Color cardBg;
    if (proposal.status == ProposalStatus.approved) {
      cardBg = const Color(0xFFE8F8F5); // Soft mint green
    } else if (proposal.status == ProposalStatus.rejected) {
      cardBg = const Color(0xFFFDEDEC); // Soft light pink/red
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: _getTypeColor(proposal.type),
                  ),
                ),
              ),
              if (proposal.status == ProposalStatus.approved)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 16),
                    SizedBox(width: 4),
                    Text('Đã duyệt', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                )
              else if (proposal.status == ProposalStatus.rejected)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel_rounded, color: AppTheme.red, size: 16),
                    SizedBox(width: 4),
                    Text('Đã từ chối', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded, color: Colors.orange, size: 13),
                      SizedBox(width: 4),
                      Text('Chờ xác nhận', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            proposal.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (proposal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              proposal.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
          ],
          if (proposal.type == ProposalType.urgentEvent)
            _buildUrgentEventDetails(context, proposal),
          const SizedBox(height: 12),

          // Confirmations list
          if (proposal.confirmations.isNotEmpty) ...[
            Text(
              'Tiến độ xác nhận (${proposal.confirmations.where((c) => c.status == ProposalConfirmationStatus.confirmed).length}/${proposal.confirmations.length}):',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
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
                    statusIcon = Icons.check_circle_rounded;
                    statusLabel = 'Đồng ý';
                    break;
                  case ProposalConfirmationStatus.rejected:
                    statusColor = AppTheme.red;
                    statusIcon = Icons.cancel_rounded;
                    statusLabel = 'Từ chối';
                    break;
                  case ProposalConfirmationStatus.pending:
                    statusColor = Colors.orange;
                    statusIcon = Icons.hourglass_top_rounded;
                    statusLabel = 'Chờ';
                    break;
                }

                return Chip(
                  avatar: Icon(statusIcon, color: statusColor, size: 16),
                  label: Text(
                    isMe ? 'Bạn ($statusLabel)' : statusLabel,
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
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
                      onPressed: () => _respond(
                        ProposalConfirmationStatus.confirmed,
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
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
                        reason: 'Bận, không thể tham gia.',
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Bận rồi'),
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
                      onPressed: () => _respond(ProposalConfirmationStatus.confirmed),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Đồng ý'),
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
                      onPressed: () => _respond(ProposalConfirmationStatus.rejected),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Từ chối'),
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
                  ? '✅ Bạn đã xác nhận đồng ý.'
                  : '❌ Bạn đã từ chối yêu cầu này.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: proposal.hasUserConfirmed(widget.currentUserId) ? AppTheme.green : AppTheme.red,
              ),
            ),
          ] else if (!isTarget) ...[
            Text(
              '👁️ Bạn đang xem yêu cầu dành cho thành viên khác.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUrgentEventDetails(
    BuildContext context,
    ActionProposalModel proposal,
  ) {
    try {
      final payload = jsonDecode(proposal.payloadJson) as Map<String, dynamic>;
      final deadline = payload['deadlineMinutes'];
      final chores = payload['chores'] as List<dynamic>? ?? const [];
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.deepOrange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thời hạn: $deadline phút sau khi tất cả đồng ý',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...chores.map((raw) {
              final chore = Map<String, dynamic>.from(raw as Map);
              return Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '• ${chore['name']} (+${chore['karmaPoints']} Karma)',
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
