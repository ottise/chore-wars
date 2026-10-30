import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_states.dart';
import '../providers/chore_providers.dart';

final legacyOccurrenceHouseProvider = FutureProvider.autoDispose
    .family<String, String>((ref, id) async {
      final occurrence = await ref
          .watch(choreRepositoryProvider)
          .getOccurrence(id);
      final house = occurrence.houseId;
      if (house == null || house.isEmpty) {
        throw StateError('The chore link could not be resolved.');
      }
      return house;
    });

/// Resolve through the membership-protected occurrence API, never currentHouse.
class LegacyChoreRedirectScreen extends ConsumerWidget {
  const LegacyChoreRedirectScreen({required this.occurrenceId, super.key});
  final String occurrenceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(legacyOccurrenceHouseProvider(occurrenceId));
    return Scaffold(
      appBar: AppBar(title: const Text('Open chore')),
      body: resolved.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () =>
              ref.invalidate(legacyOccurrenceHouseProvider(occurrenceId)),
        ),
        data: (house) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/houses/$house/chores/$occurrenceId');
            }
          });
          return const LoadingView();
        },
      ),
    );
  }
}
