import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/action_proposal_model.dart';
import '../../providers/action_proposal_providers.dart';
import 'urgent_campaign_dialog.dart';

class UrgentCampaignNotification extends ConsumerWidget {
  const UrgentCampaignNotification({required this.houseId, super.key});

  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalAsync = ref.watch(activeUrgentEventForHouseProvider(houseId));
    final proposal = proposalAsync.asData?.value;
    if (proposal == null) return const SizedBox.shrink();

    final myUserId = ref
        .watch(userProfileProvider)
        .asData
        ?.value
        .id
        .trim()
        .toLowerCase();

    final info = _parseUrgentInfo(proposal, myUserId);
    if (!info.shouldShow) return const SizedBox.shrink();

    final deadlineLabel = _formatDeadlineLabel(proposal.expiresAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Tooltip(
        message: 'Urgent tasks',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => UrgentCampaignDialog(houseId: houseId),
            ),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1AF59E0B),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33EA580C),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '💣',
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            info.taskCount > 0 ? '${info.taskCount}' : '!',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '💥 URGENT REMINDER',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (deadlineLabel != null)
                              Text(
                                deadlineLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          proposal.title.isNotEmpty
                              ? proposal.title
                              : 'Urgent Chore Blitz',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7C2D12),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          info.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ({bool shouldShow, int taskCount, String subtitle}) _parseUrgentInfo(
    ActionProposalModel proposal,
    String? myUserId,
  ) {
    try {
      final decoded = jsonDecode(proposal.payloadJson);
      if (decoded is! Map) {
        return (
          shouldShow: true,
          taskCount: 0,
          subtitle: 'Tap to check your urgent schedule',
        );
      }
      final chores = (decoded['Chores'] ?? decoded['chores']) as List? ?? [];
      if (chores.isEmpty) {
        return (
          shouldShow: true,
          taskCount: 0,
          subtitle: 'Tap to check your urgent schedule',
        );
      }
      final taskMaps = chores.whereType<Map>().toList();
      if (myUserId != null && myUserId.isNotEmpty) {
        final myTasks = taskMaps.where((task) {
          final assigned =
              (task['AssignedUserId'] ?? task['assignedUserId'])
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';
          return assigned == myUserId;
        }).toList();
        if (myTasks.isEmpty) {
          // The active campaign is household-wide. A member may have no
          // assigned chores in the newest campaign while another active
          // campaign (or the rest of this event) still needs attention.
          // Keep the reminder visible instead of hiding the bomb entirely.
          return (
            shouldShow: true,
            taskCount: taskMaps.length,
            subtitle: 'Household urgent tasks · Tap to view',
          );
        }
        final names = myTasks
            .map((t) => (t['Name'] ?? t['name'] ?? '').toString().trim())
            .where((n) => n.isNotEmpty)
            .toList();
        final preview = names.isEmpty
            ? '${myTasks.length} urgent task${myTasks.length == 1 ? '' : 's'} assigned to you'
            : '${myTasks.length} urgent task${myTasks.length == 1 ? '' : 's'}: ${names.join(', ')}';
        return (
          shouldShow: true,
          taskCount: myTasks.length,
          subtitle: preview,
        );
      }
      final allNames = taskMaps
          .map((t) => (t['Name'] ?? t['name'] ?? '').toString().trim())
          .where((n) => n.isNotEmpty)
          .toList();
      return (
        shouldShow: true,
        taskCount: taskMaps.length,
        subtitle: allNames.isEmpty
            ? '${taskMaps.length} urgent tasks · Tap to view'
            : allNames.join(' · '),
      );
    } catch (_) {
      return (
        shouldShow: true,
        taskCount: 0,
        subtitle: 'Tap to check your urgent schedule',
      );
    }
  }

  String? _formatDeadlineLabel(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    final diff = expiresAt.difference(now);
    if (diff <= Duration.zero) return null;
    final vnTime = expiresAt.toUtc().add(const Duration(hours: 7));
    final vnNow = now.toUtc().add(const Duration(hours: 7));
    final isTomorrow =
        vnTime.year == vnNow.year &&
        vnTime.month == vnNow.month &&
        vnTime.day == vnNow.day + 1;
    final timeStr = DateFormat('HH:mm').format(vnTime);
    if (isTomorrow) {
      return '⏰ Tomorrow $timeStr';
    }
    if (diff.inHours >= 1) {
      final h = diff.inHours;
      final m = diff.inMinutes.remainder(60);
      return '⏰ ${h}h ${m}m left';
    }
    return '⏰ ${diff.inMinutes.clamp(1, 59)}m left';
  }
}
