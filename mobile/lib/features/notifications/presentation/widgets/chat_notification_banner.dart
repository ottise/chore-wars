import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/session_provider.dart';
import '../../../../core/utils/api_error_message.dart';
import '../providers/notification_providers.dart';

class ChatNotificationBanner extends ConsumerStatefulWidget {
  const ChatNotificationBanner({
    required this.location,
    required this.child,
    this.houseId,
    super.key,
  });

  final String location;
  final String? houseId;
  final Widget child;

  @override
  ConsumerState<ChatNotificationBanner> createState() =>
      _ChatNotificationBannerState();
}

class _ChatNotificationBannerState
    extends ConsumerState<ChatNotificationBanner> {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _banner;

  void _closeBanner() {
    final banner = _banner;
    _banner = null;
    banner?.close();
  }

  @override
  void didUpdateWidget(covariant ChatNotificationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) _closeBanner();
  }

  @override
  void dispose() {
    _closeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionEpochProvider, (_, _) => _closeBanner());
    ref.listen(
      notificationNotifierProvider.select((state) => state.latestArrival),
      (_, notification) {
        if (notification == null ||
            (widget.houseId != null &&
                notification.houseId != widget.houseId) ||
            !(notification.isChat ||
                notification.isTaskRequest ||
                notification.isSupply) ||
            notification.isRead) {
          return;
        }
        final destination = notification.destination;
        if (destination == widget.location) return;
        final epoch = ref.read(sessionEpochProvider);
        _closeBanner();
        final banner = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  notification.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            action: destination == null
                ? null
                : SnackBarAction(
                    label: 'Open',
                    onPressed: () async {
                      if (!mounted || ref.read(sessionEpochProvider) != epoch) {
                        return;
                      }
                      try {
                        await ref
                            .read(notificationNotifierProvider.notifier)
                            .markAsRead(notification.id);
                      } catch (error) {
                        if (context.mounted &&
                            mounted &&
                            ref.read(sessionEpochProvider) == epoch) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(apiErrorMessage(error))),
                          );
                        }
                      }
                      if (context.mounted &&
                          mounted &&
                          ref.read(sessionEpochProvider) == epoch) {
                        context.go(destination);
                      }
                    },
                  ),
          ),
        );
        _banner = banner;
        banner.closed.then((_) {
          if (identical(_banner, banner)) _banner = null;
        });
      },
    );
    return widget.child;
  }
}
