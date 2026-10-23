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
    super.key,
  });

  final String location;
  final Widget child;

  @override
  ConsumerState<ChatNotificationBanner> createState() =>
      _ChatNotificationBannerState();
}

class _ChatNotificationBannerState
    extends ConsumerState<ChatNotificationBanner> {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _banner;

  @override
  void dispose() {
    _banner?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionEpochProvider, (_, _) => _banner?.close());
    ref.listen(
      notificationNotifierProvider.select((state) => state.latestArrival),
      (_, notification) {
        if (notification == null ||
            !notification.isChat ||
            notification.isRead) {
          return;
        }
        final destination = notification.destination;
        if (destination == widget.location) return;
        final epoch = ref.read(sessionEpochProvider);
        _banner?.close();
        _banner = ScaffoldMessenger.of(context).showSnackBar(
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
      },
    );
    return widget.child;
  }
}
