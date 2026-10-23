import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatHomeScreen extends StatelessWidget {
  const ChatHomeScreen({required this.houseId, super.key});
  final String houseId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in [
            (
              title: 'AI Assistant',
              subtitle: 'Private help with chores and schedules',
              icon: Icons.smart_toy_outlined,
              path: 'assistant',
            ),
            (
              title: 'Household Chat',
              subtitle: 'Your shared household conversation',
              icon: Icons.forum_outlined,
              path: 'everyone',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Icon(entry.icon),
                  ),
                  title: Text(entry.title),
                  subtitle: Text(entry.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      context.push('/houses/$houseId/chat/${entry.path}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
