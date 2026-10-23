import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../../house/domain/entities/house_models.dart';
import '../../../house/presentation/providers/current_house_provider.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({this.houseId, super.key});
  final String? houseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final selectedHouse = houseId ?? ref.watch(currentHouseProvider);
    final colors = Theme.of(context).colorScheme;
    final house = selectedHouse == null
        ? null
        : ref.watch(houseDetailProvider(selectedHouse)).asData?.value;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Account',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Schedule & Log'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            profile.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(userProfileProvider),
              ),
              data: (user) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant
                            .withValues(alpha: .35),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  user.displayName.isEmpty
                                      ? '?'
                                      : user.displayName.characters.first
                                            .toUpperCase(),
                                  style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (house != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          house.myRole == HouseRole.owner
                                              ? 'Owner'
                                              : 'Member',
                                          style: TextStyle(
                                            color: colors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 5),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  context.push('/profile/edit', extra: user),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit Profile'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (selectedHouse != null) ...[
                    Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant
                              .withValues(alpha: .35),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Karma Score',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 20),
                            ref
                                .watch(karmaSummaryProvider(selectedHouse))
                                .when(
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (error, _) => ErrorView(
                                    error: error,
                                    onRetry: () => ref.invalidate(
                                      karmaSummaryProvider(selectedHouse),
                                    ),
                                  ),
                                  data: (karma) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (karma.current < 0)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Chip(
                                            label: const Text(
                                              'Needs Balance',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                            backgroundColor:
                                                colors.errorContainer,
                                          ),
                                        ),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${karma.current}',
                                            style: TextStyle(
                                              fontSize: 38,
                                              fontWeight: FontWeight.w800,
                                              color: colors.onSurface,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 7,
                                            ),
                                            child: Text(
                                              'KARMA PTS',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          for (final entry in {
                                            'Regular': karma.normalChores,
                                            'Bonus': karma.bonus,
                                            'Penalties': karma.penalties,
                                          }.entries)
                                            Expanded(
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 3,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colors
                                                      .surfaceContainerLowest,
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  border: Border.all(
                                                    color: entry.value < 0
                                                        ? colors.error
                                                              .withValues(
                                                                alpha: .18,
                                                              )
                                                        : colors.outlineVariant
                                                              .withValues(
                                                                alpha: .35,
                                                              ),
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      entry.key,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: colors
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      '${entry.value > 0 ? '+' : ''}${entry.value}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: entry.value < 0
                                                            ? colors.error
                                                            : colors.onSurface,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            const Divider(height: 30),
                            Center(
                              child: TextButton(
                                onPressed: () => context.push(
                                  '/houses/$selectedHouse/karma/history',
                                ),
                                child: const Text(
                                  'View Karma History & Penalty Log',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant
                              .withValues(alpha: .35),
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Icon(
                              Icons.home_outlined,
                              color: colors.primary,
                            ),
                            title: const Text(
                              'Household Chores',
                              style: TextStyle(fontSize: 13),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                context.push('/houses/$selectedHouse/chores'),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1),
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Icon(
                              Icons.notifications_none_rounded,
                              color: colors.primary,
                            ),
                            title: const Text(
                              'My Notifications',
                              style: TextStyle(fontSize: 13),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/notifications'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(
                        color: colors.error.withValues(alpha: .25),
                      ),
                    ),
                    onPressed: () => _confirmLogout(context, ref),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Log Out'),
                  ),
                ],
              ),
            ),
            selectedHouse == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Choose a house to view and edit your schedule.',
                      ),
                    ),
                  )
                : _ScheduleSettings(houseId: selectedHouse),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your houses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    } catch (error) {
      if (context.mounted) {
        showAppMessage(context, apiErrorMessage(error), error: true);
      }
    }
  }
}

class _ScheduleSettings extends ConsumerWidget {
  const _ScheduleSettings({required this.houseId});
  final String houseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(activeSeasonProvider(houseId))
      .when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(activeSeasonProvider(houseId)),
        ),
        data: (season) => season == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No season is available to configure your schedule.',
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    season['name']?.toString() ?? 'Current Season',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set your availability, preferences and capacity to help plan household chores.',
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Weekly Availability'),
                    subtitle: const Text(
                      'Choose the days and times you are available',
                    ),
                    onTap: () => context.push(
                      '/houses/$houseId/seasons/${season['id']}/availability',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Chore Preferences & Capacity'),
                    subtitle: const Text(
                      'Your preferred chores and workload limits',
                    ),
                    onTap: () => context.push(
                      '/houses/$houseId/seasons/${season['id']}/member-settings',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Season Schedule'),
                    onTap: () => context.push(
                      '/houses/$houseId/seasons/${season['id']}/review',
                    ),
                  ),
                ],
              ),
      );
}
