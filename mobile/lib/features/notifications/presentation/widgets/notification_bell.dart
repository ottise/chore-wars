import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notification_providers.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({this.houseId, super.key});
  final String? houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = houseId == null
        ? ref.watch(unreadNotificationCountProvider)
        : ref.watch(unreadHouseNotificationCountProvider(houseId!));
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push(
        Uri(
          path: '/notifications',
          queryParameters: houseId == null ? null : {'houseId': houseId!},
        ).toString(),
      ),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
        child: const Icon(Icons.notifications_none_outlined),
      ),
    );
  }
}
