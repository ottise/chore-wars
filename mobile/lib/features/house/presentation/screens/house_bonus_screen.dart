import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_states.dart';
import '../providers/house_providers.dart';
import 'bonus_chores_screen.dart';

class HouseBonusScreen extends ConsumerWidget {
  const HouseBonusScreen({required this.houseId, super.key});
  final String houseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(activeSeasonProvider(houseId))
      .when(
        loading: () => const Scaffold(body: LoadingView()),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Bonus')),
          body: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(activeSeasonProvider(houseId)),
          ),
        ),
        data: (season) => season == null
            ? Scaffold(
                appBar: AppBar(title: const Text('Bonus')),
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No season yet. Bonus chores appear when extra tasks are available during a season.',
                    ),
                  ),
                ),
              )
            : BonusChoresScreen(
                houseId: houseId,
                seasonId: season['id'].toString(),
                key: ValueKey(season['id']),
              ),
      );
}
