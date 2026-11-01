import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notification_providers.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({
    this.houseId,
    this.style,
    this.iconSize,
    super.key,
  });
  final String? houseId;
  final ButtonStyle? style;
  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = houseId == null
        ? ref.watch(unreadNotificationCountProvider)
        : ref.watch(unreadHouseNotificationCountProvider(houseId!));
    return IconButton(
      tooltip: 'Notifications',
      style: style,
      onPressed: () => context.push(
        Uri(
          path: '/notifications',
          queryParameters: houseId == null ? null : {'houseId': houseId!},
        ).toString(),
      ),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
        child: Icon(Icons.notifications_none_outlined, size: iconSize),
      ),
    );
  }
}
