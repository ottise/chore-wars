import '../../../../core/widgets/app_page_bar.dart';
import '../widgets/profile_karma_card.dart';
import '../widgets/google_sign_in_button.dart';
import '../../../../core/widgets/app_page_frame.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/avatar_provider.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../../house/domain/entities/house_models.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({this.houseId, super.key});
  final String? houseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AppPageFrame(builder: (context) => _buildScreen(context, ref));

  Widget _buildScreen(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final selectedHouse = houseId;
    final colors = Theme.of(context).colorScheme;
    final house = selectedHouse == null
        ? null
        : ref.watch(houseDetailProvider(selectedHouse)).asData?.value;
    return DefaultTabController(
      length: selectedHouse == null ? 1 : 2,
      child: Scaffold(
        appBar: AppPageBar(
          title: 'My Account',
          subtitle: house?.name,
          centerTitle: true,
        ),
        body: Column(
          children: [
            if (selectedHouse != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: colors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(4),
                    dividerHeight: 0,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    tabs: const [
                      Tab(height: 40, text: 'Profile'),
                      Tab(height: 40, text: 'Chore Settings'),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  profile.when(
                    loading: () => const LoadingView(),
                    error: (error, _) => ErrorView(
                      error: error,
                      onRetry: () => ref.invalidate(userProfileProvider),
                    ),
                    data: (user) => ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _ProfileAvatar(
                                      displayName: user.displayName,
                                      avatarUrl: user.avatarUrl,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                user.displayName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (house != null)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: colors.primaryFixed,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    house.myRole ==
                                                            HouseRole.owner
                                                        ? 'Owner'
                                                        : 'Member',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: colors.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            user.email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                          if (house != null) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              house.name,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 28),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => context.push(
                                      '/profile/edit',
                                      extra: user,
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(44, 36),
                                      textStyle: const TextStyle(
                                        fontFamily: AppPageFrame.fontFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'Edit Profile Information',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (user.googleLinked)
                          const ListTile(
                            title: Text('Google account linked'),
                            leading: Icon(Icons.check_circle_outline),
                          )
                        else
                          GoogleSignInButton(
                            title: 'Link Google',
                            onToken: (token) async {
                              try {
                                await ref
                                    .read(authRepositoryProvider)
                                    .linkGoogle(token);
                                ref.invalidate(userProfileProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Google account linked.'),
                                    ),
                                  );
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(apiErrorMessage(error)),
                                    ),
                                  );
                                }
                              }
                            },
                            onError: (message) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            },
                          ),
                        if (selectedHouse != null) ...[
                          const SizedBox(height: 24),
                          ref
                              .watch(karmaSummaryProvider(selectedHouse))
                              .when(
                                loading: () => const LinearProgressIndicator(),
                                error: (error, _) => ErrorView(
                                  error: error,
                                  onRetry: () => ref.invalidate(
                                    karmaSummaryProvider(selectedHouse),
                                  ),
                                ),
                                data: (karma) => ProfileKarmaCard(
                                  karma: karma,
                                  houseId: selectedHouse,
                                ),
                              ),
                          const SizedBox(height: 24),
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: Icon(
                                    Icons.payments_outlined,
                                    color: colors.primary,
                                  ),
                                  title: const Text('Payment History'),
                                  subtitle: const Text(
                                    'Your money in and money out',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_outlined,
                                    size: 18,
                                  ),
                                  onTap: () => context.push(
                                    '/houses/$selectedHouse/account/payments',
                                  ),
                                ),
                                const Divider(indent: 16, endIndent: 16),
                                ListTile(
                                  leading: Icon(
                                    Icons.receipt_long_outlined,
                                    color: colors.primary,
                                  ),
                                  title: const Text('My Debts'),
                                  subtitle: const Text(
                                    'What I owe and what others owe me',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_outlined,
                                  ),
                                  onTap: () => context.push(
                                    '/houses/$selectedHouse/account/debts',
                                  ),
                                ),
                                const Divider(indent: 16, endIndent: 16),
                                ListTile(
                                  leading: Icon(
                                    Icons.home_outlined,
                                    color: colors.primary,
                                  ),
                                  title: const Text('Household Chores'),
                                  subtitle: const Text('Your assigned chores'),
                                  trailing: const Icon(
                                    Icons.chevron_right_outlined,
                                    size: 18,
                                  ),
                                  onTap: () => context.push(
                                    '/houses/$selectedHouse/chores?tab=mine',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                          ),
                          onPressed: () => _confirmLogout(context, ref),
                          icon: const Icon(Icons.logout_outlined, size: 16),
                          label: const Text('Log Out'),
                        ),
                      ],
                    ),
                  ),
                  if (selectedHouse != null)
                    _ScheduleSettings(houseId: selectedHouse),
                ],
              ),
            ),
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

class _ProfileAvatar extends ConsumerWidget {
  const _ProfileAvatar({required this.displayName, this.avatarUrl});
  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Text(
        displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase(),
        style: TextStyle(
          color: colors.primary,
          fontSize: 25,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: colors.primaryFixed,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl?.isNotEmpty == true
          ? Semantics(
              label: 'Profile photo',
              image: true,
              child: ref
                  .watch(accountAvatarProvider(avatarUrl!))
                  .when(
                    data: (bytes) => bytes == null
                        ? fallback
                        : Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => fallback,
                          ),
                    loading: () => fallback,
                    error: (_, _) => fallback,
                  ),
            )
          : fallback,
    );
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
        data: (season) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Set your availability, preferences and capacity to help plan household chores.',
            ),
            const SizedBox(height: 24),
            if (season == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'A season is needed to edit your availability and preferences.',
                ),
              ),
            ListTile(
              title: const Text('Weekly Availability'),
              subtitle: const Text(
                'Choose the days and times you are available',
              ),
              onTap: season == null
                  ? null
                  : () => context.push(
                      '/houses/$houseId/seasons/${season['id']}/availability',
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Chore Preferences & Capacity'),
              subtitle: const Text('Your preferred chores and workload limits'),
              onTap: season == null
                  ? null
                  : () => context.push(
                      '/houses/$houseId/seasons/${season['id']}/member-settings',
                    ),
            ),
          ],
        ),
      );
}
