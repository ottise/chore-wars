import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../house/presentation/providers/current_house_provider.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../../gamification/presentation/screens/leaderboard_screen.dart' as gamification;

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houseId = ref.watch(currentHouseProvider);

    if (houseId == null || houseId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leaderboard')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyState(
                message: 'Join a house to view the leaderboard.',
                icon: Icons.emoji_events_outlined,
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

    final activeSeasonAsync = ref.watch(activeSeasonProvider(houseId));

    return activeSeasonAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Leaderboard')),
        body: const LoadingView(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Leaderboard')),
        body: const Center(child: Text('Error loading season')),
      ),
      data: (season) {
        if (season == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Leaderboard')),
            body: const EmptyState(
              message: 'No active season. Start a season to see rankings.',
              icon: Icons.calendar_today_outlined,
            ),
          );
        }
        return gamification.LeaderboardScreen(
          houseId: houseId,
          seasonId: season['id'].toString(),
        );
      },
    );
  }
}