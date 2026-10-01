import '../../../../core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
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
    final activeSeason = ref.watch(activeSeasonProvider(houseId));

    return Scaffold(
      appBar: AppBar(
        title: house.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const Text('House'),
          data: (h) => Text(h.name),
        ),
        actions: [
          house.whenData(
            (h) => IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(
                '/houses/$houseId/settings',
                extra: h,
              ),
            ),
          ).value ??
              const SizedBox.shrink(),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshHouseState(ref, houseId: houseId);
          await ref.read(houseDetailProvider(houseId).future);
        },
        child: house.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => refreshHouseState(ref, houseId: houseId),
          ),
          data: (h) => _HouseBody(
            house: h,
            members: members,
            activeSeason: activeSeason,
            houseId: houseId,
          ),
        ),
      ),
    );
  }
}

class _HouseBody extends ConsumerWidget {
  const _HouseBody({
    required this.house,
    required this.members,
    required this.activeSeason,
    required this.houseId,
  });

  final House house;
  final AsyncValue<List<HouseMember>> members;
  final AsyncValue<Map<String, dynamic>?> activeSeason;
  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _HeaderCard(house: house),
        const SizedBox(height: 20),
        _QuickActions(house: house, houseId: houseId, activeSeason: activeSeason),
        const SizedBox(height: 24),
        if (activeSeason.value == null)
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.primaryContainer,
            leading: const Icon(Icons.add_task_rounded),
            title: const Text('Start new season'),
            subtitle: const Text('Create a season to assign chores'),
            onTap: () => context.push('/houses/$houseId/seasons/new'),
          )
        else if (activeSeason.value!['status'] == 0)
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.secondaryContainer,
            leading: const Icon(Icons.auto_awesome_rounded),
            title: const Text('Generate Schedule'),
            subtitle: const Text('AI will allocate chores based on availability'),
            onTap: () async {
              try {
                final dio = ref.read(dioProvider);
                await dio.post('/houses/$houseId/seasons/${activeSeason.value!['id']}/generate-schedule');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule generated!')));
                  refreshHouseState(ref, houseId: houseId);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
          )
        else if (activeSeason.value!['status'] == 1)
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.tertiaryContainer,
            leading: const Icon(Icons.rate_review_rounded),
            title: const Text('Review Schedule'),
            subtitle: const Text('Review and confirm the generated schedule'),
            onTap: () => context.push('/houses/$houseId/seasons/${activeSeason.value!['id']}/review'),
          ),
        const SizedBox(height: 24),
        Text('Members', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        members.when(
          loading: () => const LoadingView(),
          error: (e, _) => Text(e.toString()),
          data: (list) => Column(
            children: list
                .where((m) => m.isActive)
                .map((m) => _MemberTile(member: m))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.house});
  final House house;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.purple,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.home_work_rounded,
              color: AppTheme.yellow,
              size: 36,
            ),
            const SizedBox(height: 16),
            Text(
              house.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                house.myRole.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.house, required this.houseId, this.activeSeason});
  final House house;
  final String houseId;
  final AsyncValue<Map<String, dynamic>?>? activeSeason;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionChip(
          icon: Icons.cleaning_services_rounded,
          label: 'Chores',
          onTap: () => context.push('/houses/$houseId/chores'),
        ),
        _ActionChip(
          icon: Icons.people_outline_rounded,
          label: 'Members',
          onTap: () => context.push('/houses/$houseId/members'),
        ),
        _ActionChip(
          icon: Icons.bolt_rounded,
          label: 'Karma',
          onTap: () => context.push('/houses/$houseId/karma'),
        ),
        if (house.myRole == HouseRole.owner)
          _ActionChip(
            icon: Icons.qr_code_rounded,
            label: 'Invite QR',
            onTap: () => context.push('/houses/$houseId/qr-invite', extra: house),
          ),
        if (activeSeason?.value != null)
          _ActionChip(
            icon: Icons.tune_rounded,
            label: 'My Settings',
            onTap: () => context.push('/houses/$houseId/seasons/${activeSeason!.value!['id']}/member-settings'),
          ),
        if (activeSeason?.value != null)
          _ActionChip(
            icon: Icons.star_rounded,
            label: 'Bonus Chores',
            onTap: () => context.push('/houses/$houseId/seasons/${activeSeason!.value!['id']}/bonus-chores'),
          ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE9E7F5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.purple),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});
  final HouseMember member;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
        child: Text(
          member.displayName.isNotEmpty
              ? member.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: AppTheme.purple,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        member.displayName,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      trailing: member.isOwner
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Owner',
                style: TextStyle(
                  color: AppTheme.purple,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            )
          : null,
    );
  }
}









