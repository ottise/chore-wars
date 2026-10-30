import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/presentation/providers/notification_providers.dart';

class AssistantShortcut extends ConsumerWidget {
  const AssistantShortcut({required this.houseId, super.key});
  final String houseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadAssistantCountProvider(houseId));
    return Badge(
      isLabelVisible: unread > 0,
      label: Text(unread > 10 ? '10+' : '$unread'),
      child: FloatingActionButton.small(
        heroTag: 'house-assistant-shortcut',
        tooltip: unread > 0
            ? 'AI Assistant, $unread unread requests'
            : 'Ask AI',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/houses/$houseId/chat/assistant'),
        child: const Icon(Icons.smart_toy_outlined),
      ),
    );
  }
}
