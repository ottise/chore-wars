import '../widgets/household_calendar.dart';
import '../providers/house_calendar_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/house_models.dart';
import '../providers/house_providers.dart';

class HouseDetailScreen extends ConsumerWidget {
  const HouseDetailScreen({required this.houseId, super.key});
  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final house = ref.watch(houseDetailProvider(houseId));
    final members = ref.watch(houseMembersProvider(houseId));
    final season = ref.watch(activeSeasonProvider(houseId));
    final me = ref.watch(userProfileProvider).asData?.value.id;
    final colors = Theme.of(context).colorScheme;
    final base = '/houses/$houseId';
    return Scaffold(
      body: house.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => refreshHouseState(ref, houseId: houseId),
        ),
        data: (h) => RefreshIndicator(
          onRefresh: () async {
            refreshHouseState(ref, houseId: houseId);
            ref.invalidate(houseCalendarProvider);
            await Future.wait([
              ref.read(houseDetailProvider(houseId).future),
              ref.read(houseMembersProvider(houseId).future),
              ref.read(activeSeasonProvider(houseId).future),
            ]);
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Text(
                    'Your shared space',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Overview',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1,
                                color: colors.onSurface,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('$base/more'),
                        child: const Text('House Management'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  HouseholdCalendar(houseId: houseId),
                  const SizedBox(height: 24),
                  season.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => ErrorView(
                      error: error,
                      onRetry: () =>
                          ref.invalidate(activeSeasonProvider(houseId)),
                    ),
                    data: (value) => _SeasonCard(
                      houseId: houseId,
                      owner: h.myRole == HouseRole.owner,
                      season: value,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Member',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      if (members.asData != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryFixed,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${members.asData!.value.where((m) => m.isActive).length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.onPrimaryFixedVariant,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (h.myRole == HouseRole.owner)
                        TextButton(
                          onPressed: () => context.push('$base/members'),
                          child: const Text('Manage'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  members.when(
                    loading: () => const LoadingView(),
                    error: (error, _) => ErrorView(
                      error: error,
                      onRetry: () =>
                          ref.invalidate(houseMembersProvider(houseId)),
                    ),
                    data: (list) {
                      final active = list.where((m) => m.isActive).toList();
                      return _Surface(
                        child: active.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No member information available.'),
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < active.length; i++) ...[
                                    if (i > 0)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Divider(height: 1),
                                      ),
                                    _MemberTile(
                                      member: active[i],
                                      onTap: active[i].userId == me
                                          ? () => context.push('$base/account')
                                          : null,
                                    ),
                                  ],
                                ],
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'YOUR HOUSEHOLD',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _Surface(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline_rounded),
                          title: const Text('My Profile & Schedule'),
                          trailing: const Icon(Icons.chevron_right_outlined),
                          onTap: () => context.push('$base/account'),
                        ),
                        if (season.asData?.value?['id'] != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1),
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_month_outlined),
                            title: const Text('Household Summary'),
                            trailing: const Icon(Icons.chevron_right_outlined),
                            onTap: () => context.push(
                              '$base/seasons/${season.asData!.value!['id']}/review',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({
    required this.houseId,
    required this.owner,
    required this.season,
  });
  final String houseId;
  final bool owner;
  final Map<String, dynamic>? season;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = '/houses/$houseId';
    final status = season?['status'];
    final confirmed = season?['currentUserConfirmationStatus'] == 1;
    final (title, detail, action, path) = switch (status) {
      null => (
        'Start Your First Season',
        owner ? 'Create a season to plan and share household chores.' : 'The owner will create a season and prepare the household schedule.',
        owner ? 'Create New Season' : null,
        '$base/seasons/new',
      ),
      0 => (
        'Preparing a New Season',
        owner
            ? 'Build a schedule, assign chores and submit it for review.'
            : 'The owner is preparing the chore schedule.',
        owner ? 'Prepare Schedule' : null,
        '$base/seasons/${season!['id']}/review',
      ),
      1 => (
        confirmed
            ? 'You Have Approved the Schedule'
            : 'Schedule Awaiting Approval',
        '${season!['confirmedCount'] ?? 0}/${season!['requiredConfirmationCount'] ?? 0} members have approved. Everyone must agree before the season starts.',
        'Household Summary',
        '$base/seasons/${season!['id']}/review',
      ),
      2 => (
        'Keep Your Household on Track',
        'The season is active. Check your assigned chores and update your progress.',
        'View Chores',
        '$base/chores',
      ),
      _ => (
        'Season Completed',
        'Review your household schedule and results.',
        'Review Season',
        '$base/seasons/${season!['id']}/review',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryFixed,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: colors.onPrimaryFixedVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Current Season',
                style: TextStyle(
                  color: colors.onPrimaryFixedVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.onPrimaryFixed,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: TextStyle(color: colors.onPrimaryFixedVariant, height: 1.5),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push(path),
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant
            .withValues(alpha: .35),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, this.onTap});
  final HouseMember member;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: member.isOwner
              ? colors.primaryFixed
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          member.displayName.isEmpty
              ? '?'
              : member.displayName.characters.first.toUpperCase(),
          style: TextStyle(
            color: member.isOwner
                ? colors.onPrimaryFixedVariant
                : colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        member.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(member.isOwner ? 'Owner' : 'Member'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: member.isOwner
              ? colors.primaryFixed
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          member.isOwner ? 'Owner' : 'Member',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: member.isOwner
                ? colors.onPrimaryFixedVariant
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
