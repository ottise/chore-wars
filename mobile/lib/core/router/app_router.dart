import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/chores/presentation/screens/chores_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/bounty/presentation/screens/bounty_board_screen.dart';
import '../../features/bounty/presentation/screens/create_bounty_screen.dart';
import '../../features/bounty/presentation/screens/bounty_detail_screen.dart';
import '../../features/payment/presentation/screens/payment_obligations_screen.dart';
import '../../features/chores/presentation/screens/chore_detail_screen.dart'
  as chores;
import '../../features/gamification/presentation/screens/karma_history_screen.dart'
  as gamification_history;
import '../widgets/app_shell.dart';

import '../constants/app_constants.dart';
import '../screens/ui_preview_screen.dart';
import '../../features/chore/domain/entities/chore_models.dart';
import '../../features/chore/presentation/screens/chore_detail_screen.dart'
  as chore_feature;
import '../../features/chore/presentation/screens/chore_form_screen.dart';
import '../../features/chore/presentation/screens/chore_list_screen.dart';
import '../../features/gamification/presentation/screens/achievements_screen.dart';
import '../../features/gamification/presentation/screens/chore_pass_screen.dart';
import '../../features/gamification/presentation/screens/karma_screen.dart';
import '../../features/gamification/presentation/screens/leaderboard_screen.dart'
  as gamification_leaderboard;
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
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => HomeScreen(
                  houseId: state.uri.queryParameters['houseId'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chores',
                builder: (context, state) => const ChoresScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leaderboard',
                builder: (context, state) => const LeaderboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => AppConstants.uiPreview
            ? const UiPreviewScreen()
            : const PlaceholderScreen(title: 'Splash / Home'),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/bounties',
        builder: (context, state) => BountyBoardScreen(
          houseId: state.uri.queryParameters['houseId'],
        ),
      ),
      GoRoute(
        path: '/bounties/create',
        builder: (context, state) => CreateBountyScreen(
          houseId: state.uri.queryParameters['houseId'],
          occurrenceId: state.uri.queryParameters['occurrenceId'],
          choreName: state.uri.queryParameters['choreName'],
          deadline: state.uri.queryParameters['deadline'],
        ),
      ),
      GoRoute(
        path: '/bounties/:bountyId',
        builder: (context, state) => BountyDetailScreen(
          houseId: state.uri.queryParameters['houseId'],
          bountyId: state.pathParameters['bountyId']!,
        ),
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => PaymentObligationsScreen(
          houseId: state.uri.queryParameters['houseId'],
        ),
      ),
      GoRoute(
        path: '/karma-history',
        builder: (context, state) => gamification_history.KarmaHistoryScreen(
          houseId: state.uri.queryParameters['houseId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/chores/:occurrenceId',
        builder: (context, state) => chores.ChoreDetailScreen(
          choreName: state.uri.queryParameters['name'] ?? 'Chore',
          dueDate: state.uri.queryParameters['due'] ?? 'Provided by the backend',
          status: state.uri.queryParameters['status'] ?? 'Unknown',
        ),
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
        builder: (context, state) => chore_feature.ChoreDetailScreen(
          houseId: state.pathParameters['houseId']!,
          occurrenceId: state.pathParameters['occurrenceId']!,
        ),
      ),
      GoRoute(
        path: '/houses/:houseId/seasons/:seasonId/leaderboard',
        builder: (context, state) => gamification_leaderboard.LeaderboardScreen(
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
            gamification_history.KarmaHistoryScreen(
              houseId: state.pathParameters['houseId']!,
            ),
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
