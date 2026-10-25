import '../../features/house/presentation/screens/unresolved_chores_screen.dart';
import '../../features/house/presentation/screens/failed_events_screen.dart';
import '../../features/gamification/presentation/screens/reward_catalog_screen.dart';
import '../../features/gamification/presentation/screens/reward_form_screen.dart';
import '../../features/payment/presentation/screens/payment_obligations_screen.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/chores/presentation/screens/chores_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/bounty/presentation/screens/bounty_board_screen.dart';
import '../../features/bounty/presentation/screens/create_bounty_screen.dart';
import '../../features/bounty/presentation/screens/bounty_detail_screen.dart';
import '../../features/chores/presentation/screens/chore_detail_screen.dart'
    as chores;
import '../../features/gamification/presentation/screens/karma_history_screen.dart'
    as gamification_history;
import '../widgets/house_shell.dart';
import '../../features/house/presentation/screens/house_more_screen.dart';
import '../../features/house/presentation/screens/house_bonus_screen.dart';
import '../constants/app_constants.dart';
import '../screens/ui_preview_screen.dart';
import '../storage/secure_storage.dart';
import '../storage/session_provider.dart';
import '../../features/auth/domain/entities/auth_models.dart';
import '../../features/auth/presentation/screens/edit_profile_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/chore/domain/entities/chore_models.dart';
import '../../features/chore/domain/entities/routine_preset.dart';
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
import '../../features/house/presentation/screens/availability_screen.dart';
import '../../features/house/presentation/screens/bonus_chores_screen.dart';
import '../../features/house/presentation/screens/create_house_screen.dart';
import '../../features/house/presentation/screens/member_settings_screen.dart';
import '../../features/house/presentation/screens/create_season_screen.dart';
import '../../features/house/presentation/screens/house_detail_screen.dart';
import '../../features/house/presentation/screens/house_onboarding_screen.dart';
import '../../features/house/presentation/screens/house_settings_screen.dart';
import '../../features/house/presentation/screens/join_house_screen.dart';
import '../../features/house/presentation/screens/member_management_screen.dart';
import '../../features/house/presentation/screens/my_houses_screen.dart';
import '../../features/house/presentation/screens/qr_invite_screen.dart';
import '../../features/house/presentation/screens/qr_join_screen.dart';
import '../../features/house/presentation/screens/review_schedule_screen.dart';
import '../../features/chat/presentation/screens/chat_room_screen.dart';
import '../../features/chat/presentation/screens/chat_home_screen.dart';
import '../../features/chat/presentation/screens/assistant_chat_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);

  final router = GoRouter(
    initialLocation: '/houses',
    redirect: (context, state) async {
      if (AppConstants.uiPreview) return null;
      final token = await secureStorage.getAccessToken();
      final isLoggedIn = token != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn &&
          (isAuthRoute ||
              state.matchedLocation == '/' ||
              state.matchedLocation == '/home')) {
        return '/houses';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/chores',
        builder: (context, state) => const ChoresScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
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
      GoRoute(
        path: '/',
        builder: (context, state) => AppConstants.uiPreview
            ? const UiPreviewScreen()
            : const Scaffold(body: Center(child: Text('Splash / Home'))),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/bounties',
        builder: (context, state) =>
            BountyBoardScreen(houseId: state.uri.queryParameters['houseId']),
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
          dueDate: state.uri.queryParameters['due'] ?? '',
          status: state.uri.queryParameters['status'] ?? 'Unknown',
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

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
          ShellRoute(
            builder: (context, state, child) => HouseShell(
              houseId: state.pathParameters['houseId']!,
              location: state.uri.path,
              child: child,
            ),
            routes: [
              GoRoute(
                path: ':houseId',
                builder: (context, state) => HouseDetailScreen(
                  houseId: state.pathParameters['houseId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'account',
                    builder: (_, state) => ProfileScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'bonus',
                    builder: (_, state) => HouseBonusScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'bounties',
                    builder: (_, state) => BountyBoardScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'chat/notifications',
                    builder: (_, state) => NotificationsScreen(
                      houseId: state.pathParameters['houseId']!,
                      chatOnly: true,
                    ),
                  ),
                  GoRoute(
                    path: 'more',
                    builder: (context, state) => HouseMoreScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => HouseSettingsScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'ai',
                    redirect: (context, state) =>
                        '/houses/${state.pathParameters['houseId']}/chat/assistant',
                    routes: [
                      GoRoute(
                        path: 'evaluations/:runId',
                        redirect: (context, state) =>
                            '/houses/${state.pathParameters['houseId']}/chat/assistant',
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'failed-events',
                    builder: (context, state) => FailedEventsScreen(
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
                    builder: (context, state) => QrInviteScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'chores',
                    builder: (context, state) => ChoreListScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'chores/new',
                    builder: (context, state) => ChoreFormScreen(
                      houseId: state.pathParameters['houseId']!,
                      createRoutine:
                          state.uri.queryParameters['routine'] == 'true',
                      preset: RoutinePreset.fromKey(
                        state.uri.queryParameters['preset'],
                      ),
                    ),
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
                    builder: (context, state) =>
                        chore_feature.ChoreDetailScreen(
                          houseId: state.pathParameters['houseId']!,
                          occurrenceId: state.pathParameters['occurrenceId']!,
                        ),
                  ),
                  GoRoute(
                    path: 'karma',
                    builder: (context, state) =>
                        KarmaScreen(houseId: state.pathParameters['houseId']!),
                  ),
                  GoRoute(
                    path: 'unresolved-chores',
                    builder: (context, state) => UnresolvedChoresScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'rewards',
                    builder: (context, state) => RewardCatalogScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'payments',
                    builder: (context, state) => PaymentObligationsScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'rewards/new',
                    builder: (context, state) => RewardFormScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) => ChatHomeScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'everyone',
                        builder: (context, state) => ChatRoomScreen(
                          houseId: state.pathParameters['houseId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'assistant',
                        builder: (context, state) => Consumer(
                          builder: (context, widgetRef, _) =>
                              AssistantChatScreen(
                                key: ValueKey((
                                  state.pathParameters['houseId'],
                                  widgetRef.watch(sessionEpochProvider),
                                )),
                                houseId: state.pathParameters['houseId']!,
                                initialPrompt: state.extra is String
                                    ? state.extra as String
                                    : null,
                                urgentMode:
                                    state.uri.queryParameters['task'] ==
                                    'urgent',
                              ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'urgent-event',
                    redirect: (context, state) =>
                        '/houses/${state.pathParameters['houseId']}/chat/assistant?task=urgent',
                  ),
                  GoRoute(
                    path: 'karma/history',
                    builder: (context, state) =>
                        gamification_history.KarmaHistoryScreen(
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
                    path: 'seasons/new',
                    builder: (context, state) => CreateSeasonScreen(
                      houseId: state.pathParameters['houseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'seasons/:seasonId/leaderboard',
                    builder: (context, state) =>
                        gamification_leaderboard.LeaderboardScreen(
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
                  GoRoute(
                    path: 'seasons/:seasonId/availability',
                    builder: (context, state) => AvailabilityScreen(
                      houseId: state.pathParameters['houseId']!,
                      seasonId: state.pathParameters['seasonId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'seasons/:seasonId/member-settings',
                    builder: (context, state) => MemberSettingsScreen(
                      houseId: state.pathParameters['houseId']!,
                      seasonId: state.pathParameters['seasonId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'seasons/:seasonId/review',
                    builder: (context, state) => ReviewScheduleScreen(
                      houseId: state.pathParameters['houseId']!,
                      seasonId: state.pathParameters['seasonId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'seasons/:seasonId/bonus-chores',
                    builder: (context, state) => BonusChoresScreen(
                      houseId: state.pathParameters['houseId']!,
                      seasonId: state.pathParameters['seasonId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.listen(sessionEpochProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
