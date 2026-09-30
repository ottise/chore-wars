import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../screens/ui_preview_screen.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/domain/entities/auth_models.dart';

import '../../features/auth/presentation/screens/edit_profile_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
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
import '../../features/house/domain/entities/house_models.dart';
import '../../features/house/presentation/screens/create_house_screen.dart';
import '../../features/house/presentation/screens/house_detail_screen.dart';
import '../../features/house/presentation/screens/house_onboarding_screen.dart';
import '../../features/house/presentation/screens/house_settings_screen.dart';
import '../../features/house/presentation/screens/join_house_screen.dart';
import '../../features/house/presentation/screens/member_management_screen.dart';
import '../../features/house/presentation/screens/my_houses_screen.dart';
import '../../features/house/presentation/screens/qr_invite_screen.dart';
import '../../features/house/presentation/screens/qr_join_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      if (AppConstants.uiPreview) return null;
      final token = await secureStorage.getAccessToken();
      final isLoggedIn = token != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/houses';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => AppConstants.uiPreview
            ? const UiPreviewScreen()
            : const SizedBox.shrink(),
      ),

      // ── Auth ────────────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Profile ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                EditProfileScreen(profile: state.extra as UserProfile),
          ),
        ],
      ),

      // ── Houses ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/houses',
        builder: (context, state) => const MyHousesScreen(),
        routes: [
          GoRoute(
            path: 'onboarding',
            builder: (context, state) => const HouseOnboardingScreen(),
          ),
          GoRoute(
            path: 'new',
            builder: (context, state) => const CreateHouseScreen(),
          ),
          GoRoute(
            path: 'join',
            builder: (context, state) => const JoinHouseScreen(),
          ),
          GoRoute(
            path: 'qr-join',
            builder: (context, state) => const QrJoinScreen(),
          ),
          GoRoute(
            path: ':houseId',
            builder: (context, state) =>
                HouseDetailScreen(houseId: state.pathParameters['houseId']!),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (context, state) => HouseSettingsScreen(
                  houseId: state.pathParameters['houseId']!,
                ),
              ),
              GoRoute(
                path: 'members',
                builder: (context, state) => MemberManagementScreen(
                  houseId: state.pathParameters['houseId']!,
                ),
              ),
              GoRoute(
                path: 'qr-invite',
                builder: (context, state) =>
                    QrInviteScreen(house: state.extra as House),
              ),

              // ── Chores ────────────────────────────────────────────────
              GoRoute(
                path: 'chores',
                builder: (context, state) =>
                    ChoreListScreen(houseId: state.pathParameters['houseId']!),
              ),
              GoRoute(
                path: 'chores/new',
                builder: (context, state) =>
                    ChoreFormScreen(houseId: state.pathParameters['houseId']!),
              ),
              GoRoute(
                path: 'chores/templates/:choreId/edit',
                builder: (context, state) => ChoreEditLoaderScreen(
                  houseId: state.pathParameters['houseId']!,
                  choreId: state.pathParameters['choreId']!,
                  initial: state.extra as ChoreTemplate?,
                ),
              ),
              GoRoute(
                path: 'chores/:occurrenceId',
                builder: (context, state) => ChoreDetailScreen(
                  houseId: state.pathParameters['houseId']!,
                  occurrenceId: state.pathParameters['occurrenceId']!,
                ),
              ),

              // ── Gamification ──────────────────────────────────────────
              GoRoute(
                path: 'karma',
                builder: (context, state) =>
                    KarmaScreen(houseId: state.pathParameters['houseId']!),
              ),
              GoRoute(
                path: 'karma/history',
                builder: (context, state) => KarmaHistoryScreen(
                  houseId: state.pathParameters['houseId']!,
                ),
              ),
              GoRoute(
                path: 'achievements',
                builder: (context, state) => AchievementsScreen(
                  houseId: state.pathParameters['houseId']!,
                ),
              ),
              GoRoute(
                path: 'seasons/:seasonId/leaderboard',
                builder: (context, state) => LeaderboardScreen(
                  houseId: state.pathParameters['houseId']!,
                  seasonId: state.pathParameters['seasonId']!,
                ),
              ),
              GoRoute(
                path: 'seasons/:seasonId/rewards',
                builder: (context, state) => SeasonRewardScreen(
                  houseId: state.pathParameters['houseId']!,
                  seasonId: state.pathParameters['seasonId']!,
                ),
              ),
              GoRoute(
                path: 'seasons/:seasonId/chore-pass/:redemptionId',
                builder: (context, state) => ChorePassScreen(
                  houseId: state.pathParameters['houseId']!,
                  seasonId: state.pathParameters['seasonId']!,
                  redemptionId: state.pathParameters['redemptionId']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
