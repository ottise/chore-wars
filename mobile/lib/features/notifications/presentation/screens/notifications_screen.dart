import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationNotifierProvider);
    final notifications = state.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () {
                ref.read(notificationNotifierProvider.notifier).markAllAsRead();
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: state.isLoading && notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const EmptyState(
                  message: 'You are all caught up.',
                  icon: Icons.notifications_none,
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(notificationNotifierProvider.notifier).loadNotifications(),
                  child: ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return ListTile(
                        onTap: () {
                          if (!n.isRead) {
                            ref.read(notificationNotifierProvider.notifier).markAsRead(n.id);
                          }
                          // Optional: Handle navigation based on n.type / n.metadata
                        },
                        leading: CircleAvatar(
                          backgroundColor: n.isRead
                              ? AppTheme.muted.withValues(alpha: 0.1)
                              : AppTheme.purple.withValues(alpha: 0.2),
                          child: Icon(
                            _getIconForType(n.type),
                            color: n.isRead ? AppTheme.muted : AppTheme.purple,
                          ),
                        ),
                        title: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                            color: n.isRead
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              n.message,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, h:mm a').format(n.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'CHORE_ASSIGNED':
      case 'CHORE_REMINDER':
        return Icons.assignment_rounded;
      case 'CHORE_OVERDUE':
        return Icons.warning_amber_rounded;
      case 'CHORE_COMPLETED':
        return Icons.check_circle_outline_rounded;
      case 'SEASON_STARTED':
      case 'SEASON_ENDED':
        return Icons.flag_rounded;
      case 'REWARD_EARNED':
        return Icons.emoji_events_rounded;
      case 'BOUNTY_POSTED':
      case 'BOUNTY_CLAIMED':
        return Icons.monetization_on_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}