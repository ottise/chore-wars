import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_page_frame.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../../core/storage/session_provider.dart';
import '../../domain/entities/notification_models.dart';
import '../providers/notification_providers.dart';

enum _NotificationFilter { all, bounty, chores, chat, other }

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({this.houseId, this.chatOnly = false, super.key});
  final String? houseId;
  final bool chatOnly;
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;
  bool _marking = false;

  _NotificationFilter _category(AppNotification item) => item.isChat
      ? _NotificationFilter.chat
      : item.type.startsWith('BOUNTY_')
      ? _NotificationFilter.bounty
      : item.type.startsWith('CHORE_')
      ? _NotificationFilter.chores
      : _NotificationFilter.other;

  Future<void> _action(Future<void> Function() callback) async {
    try {
      await callback();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppPageFrame(builder: _buildScreen);

  Widget _buildScreen(BuildContext context) {
    final state = ref.watch(notificationNotifierProvider);
    final colors = Theme.of(context).colorScheme;
    final scoped = state.notifications
        .where(
          (n) =>
              widget.chatOnly ? n.isChat && n.houseId == widget.houseId : true,
        )
        .toList();
    final items = scoped
        .where(
          (n) =>
              widget.chatOnly ||
              _filter == _NotificationFilter.all ||
              _category(n) == _filter,
        )
        .toList();
    return Scaffold(
      appBar: AppPageBar(
        title: widget.chatOnly ? 'Chat Notifications' : 'System Notifications',
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(
                fontFamily: AppPageFrame.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: _marking || !items.any((n) => !n.isRead)
                ? null
                : () async {
                    setState(() => _marking = true);
                    final unread = items.where((n) => !n.isRead).toList();
                    final epoch = ref.read(sessionEpochProvider);
                    await _action(() async {
                      for (final n in unread) {
                        if (!mounted ||
                            ref.read(sessionEpochProvider) != epoch) {
                          return;
                        }
                        await ref
                            .read(notificationNotifierProvider.notifier)
                            .markAsRead(n.id);
                      }
                    });
                    if (mounted) setState(() => _marking = false);
                  },
            child: Text(_marking ? 'Saving…' : 'Mark All Read'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.chatOnly)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  for (final entry in {
                    _NotificationFilter.all: 'All ${scoped.length}',
                    _NotificationFilter.bounty: 'Bounty',
                    _NotificationFilter.chores: 'Chores',
                    _NotificationFilter.chat: 'Chat',
                    _NotificationFilter.other: 'Other',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _filter == entry.key,
                        showCheckmark: false,
                        onSelected: _marking
                            ? null
                            : (_) => setState(() => _filter = entry.key),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(notificationNotifierProvider.notifier)
                  .loadNotifications(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (state.isLoading) const LinearProgressIndicator(),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        state.error!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  if (items.isEmpty && !state.isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 56,
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_none_outlined,
                            size: 42,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.chatOnly
                                ? 'No chat notifications in this house.'
                                : 'No notifications in this category.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: item.isRead
                            ? colors.surfaceContainerLowest
                            : Color.alphaBlend(
                                colors.primaryFixed.withValues(alpha: .25),
                                colors.surfaceContainerLowest,
                              ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: item.isRead
                                ? colors.outlineVariant.withValues(alpha: .25)
                                : colors.primaryFixedDim,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _marking
                              ? null
                              : () => _action(() async {
                                  final epoch = ref.read(sessionEpochProvider);
                                  if (!item.isRead) {
                                    await ref
                                        .read(
                                          notificationNotifierProvider.notifier,
                                        )
                                        .markAsRead(item.id);
                                  }
                                  if (context.mounted &&
                                      ref.read(sessionEpochProvider) == epoch &&
                                      item.destination != null) {
                                    context.go(item.destination!);
                                  }
                                }),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _NotificationIcon(type: item.type),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                fontWeight: item.isRead
                                                    ? FontWeight.w500
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              DateFormat.MMMd('en_US')
                                                  .add_jm()
                                                  .format(
                                                    item.createdAt.toLocal(),
                                                  ),
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          if (!item.isRead)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Tooltip(
                                                message: 'Unread',
                                                child: Icon(
                                                  Icons.circle_outlined,
                                                  size: 7,
                                                  color: colors.primary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.message,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                      if (item.destination != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'View Details →',
                                          style: TextStyle(
                                            color: colors.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.type});
  final String type;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final alert = type == 'CHORE_OVERDUE' || type == 'URGENT_EVENT';
    final bounty = type.startsWith('BOUNTY_') || type == 'PAYMENT_DUE';
    final icon = alert
        ? Icons.warning_amber_outlined
        : bounty
        ? Icons.card_giftcard_outlined
        : type.startsWith('CHORE_')
        ? Icons.task_alt_outlined
        : type.startsWith('CHAT_')
        ? Icons.alternate_email_outlined
        : Icons.notifications_none_outlined;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: alert
            ? colors.errorContainer
            : bounty
            ? colors.tertiaryFixed
            : colors.primaryFixed,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        size: 21,
        color: alert
            ? colors.onErrorContainer
            : bounty
            ? colors.onTertiaryFixedVariant
            : colors.onPrimaryFixedVariant,
      ),
    );
  }
}
