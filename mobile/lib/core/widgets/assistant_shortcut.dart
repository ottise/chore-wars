import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AssistantShortcut extends StatelessWidget {
  const AssistantShortcut({required this.houseId, super.key});
  final String houseId;
  @override
  Widget build(BuildContext context) => FloatingActionButton.small(
    heroTag: 'house-assistant-shortcut',
    tooltip: 'Ask AI',
    backgroundColor: Theme.of(context).colorScheme.primary,
    foregroundColor: Colors.white,
    onPressed: () => context.push('/houses/$houseId/chat/assistant'),
    child: const Icon(Icons.smart_toy_outlined),
  );
}
