import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../screens/ui_preview_screen.dart';
import '../../features/chore/domain/entities/chore_models.dart';
import '../../features/chore/presentation/screens/chore_detail_screen.dart';
import '../../features/chore/presentation/screens/chore_form_screen.dart';
import '../../features/chore/presentation/screens/chore_list_screen.dart';
import '../../features/gamification/presentation/screens/achievements_screen.dart';
import '../../features/gamification/presentation/screens/chore_pass_screen.dart';
import '../../features/gamification/presentation/screens/karma_history_screen.dart';
import '../../features/gamification/presentation/screens/karma_screen.dart';
import '../../features/gamification/presentation/screens/leaderboard_screen.dart';
import '../../features/gamification/presentation/screens/season_reward_screen.dart';

// Placeholder for screens we will create later
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text(title)),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => AppConstants.uiPreview
            ? const UiPreviewScreen()
            : const PlaceholderScreen(title: 'Splash / Home'),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const PlaceholderScreen(title: 'Login'),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const PlaceholderScreen(title: 'Register'),
      ),
      GoRoute(
        path: '/houses/:houseId/chores',
        builder: (context, state) =>
            ChoreListScreen(houseId: state.pathParameters['houseId']!),
      ),
      GoRoute(
        path: '/houses/:houseId/chores/new',
        builder: (context, state) =>
            ChoreFormScreen(houseId: state.pathParameters['houseId']!),
      ),
      GoRoute(
        path: '/houses/:houseId/chores/templates/:choreId/edit',
        builder: (context, state) => ChoreEditLoaderScreen(
          houseId: state.pathParameters['houseId']!,
          choreId: state.pathParameters['choreId']!,
          initial: state.extra as ChoreTemplate?,
        ),
      ),
      GoRoute(
        path: '/houses/:houseId/chores/:occurrenceId',
        builder: (context, state) => ChoreDetailScreen(
          houseId: state.pathParameters['houseId']!,
          occurrenceId: state.pathParameters['occurrenceId']!,
        ),
      ),
      GoRoute(
        path: '/houses/:houseId/seasons/:seasonId/leaderboard',
        builder: (context, state) => LeaderboardScreen(
          houseId: state.pathParameters['houseId']!,
          seasonId: state.pathParameters['seasonId']!,
        ),
      ),
      GoRoute(
        path: '/houses/:houseId/karma',
        builder: (context, state) =>
            KarmaScreen(houseId: state.pathParameters['houseId']!),
      ),
      GoRoute(
        path: '/houses/:houseId/karma/history',
        builder: (context, state) =>
            KarmaHistoryScreen(houseId: state.pathParameters['houseId']!),
      ),
      GoRoute(
        path: '/houses/:houseId/achievements',
        builder: (context, state) =>
            AchievementsScreen(houseId: state.pathParameters['houseId']!),
      ),
      GoRoute(
        path: '/houses/:houseId/seasons/:seasonId/rewards',
        builder: (context, state) => SeasonRewardScreen(
          houseId: state.pathParameters['houseId']!,
          seasonId: state.pathParameters['seasonId']!,
        ),
      ),
      GoRoute(
        path: '/houses/:houseId/seasons/:seasonId/chore-pass/:redemptionId',
        builder: (context, state) => ChorePassScreen(
          houseId: state.pathParameters['houseId']!,
          seasonId: state.pathParameters['seasonId']!,
          redemptionId: state.pathParameters['redemptionId']!,
        ),
      ),
    ],
    // redirect: (context, state) {
    //   // Add auth guard logic here later
    //   return null;
    // },
  );
});
