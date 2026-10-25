import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/session_provider.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

final chatNotificationsEnabledProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, houseId) async {
      final response = await ref
          .watch(dioProvider)
          .get('/houses/$houseId/chat/notification-settings');
      return response.data['enabled'] as bool;
    });

class ChatNotificationButton extends ConsumerStatefulWidget {
  const ChatNotificationButton({required this.houseId, super.key});
  final String houseId;
  @override
  ConsumerState<ChatNotificationButton> createState() =>
      _ChatNotificationButtonState();
}

class _ChatNotificationButtonState
    extends ConsumerState<ChatNotificationButton> {
  bool _saving = false;

  Future<void> _toggle(bool enabled) async {
    final epoch = ref.read(sessionEpochProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final houseId = widget.houseId;
    setState(() => _saving = true);
    try {
      await ref
          .read(dioProvider)
          .put(
            '/houses/$houseId/chat/notification-settings',
            data: {'enabled': !enabled},
          );
      if (container.read(sessionEpochProvider) != epoch) return;
      container.invalidate(chatNotificationsEnabledProvider(houseId));
      await container.read(chatNotificationsEnabledProvider(houseId).future);
    } catch (error) {
      if (mounted && ref.read(sessionEpochProvider) == epoch) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(
      chatNotificationsEnabledProvider(widget.houseId),
    );
    final enabled = settings.asData?.value;
    final unread = ref.watch(unreadChatCountProvider(widget.houseId));
    return Semantics(
      toggled: enabled,
      child: IconButton(
        tooltip: settings.hasError
            ? 'Retry Chat Notification Settings'
            : enabled == false
            ? 'Enable Chat Notifications'
            : 'Mute Chat Notifications',
        icon: _saving || settings.isLoading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Badge(
                isLabelVisible: enabled == true && unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: Icon(
                  enabled == false
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_none_outlined,
                ),
              ),
        onPressed: _saving || settings.isLoading
            ? null
            : enabled == null
            ? () => ref.invalidate(
                chatNotificationsEnabledProvider(widget.houseId),
              )
            : () => _toggle(enabled),
      ),
    );
  }
}
