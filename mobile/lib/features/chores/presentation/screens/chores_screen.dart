import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../house/presentation/providers/current_house_provider.dart';
import '../../../chore/presentation/screens/chore_list_screen.dart';

class ChoresScreen extends ConsumerWidget {
  const ChoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houseId = ref.watch(currentHouseProvider);

    if (houseId == null || houseId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chores')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyState(
                message: 'Join a house to manage chores.',
                icon: Icons.checklist_outlined,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/houses'),
                icon: const Icon(Icons.other_houses_outlined),
                label: const Text('View My Houses'),
              ),
            ],
          ),
        ),
      );
    }

    return ChoreListScreen(houseId: houseId);
  }
}
