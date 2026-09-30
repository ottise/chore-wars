import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/house_models.dart';
import '../providers/house_providers.dart';

class MemberManagementScreen extends ConsumerWidget {
  const MemberManagementScreen({required this.houseId, super.key});

  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houseAsync = ref.watch(houseDetailProvider(houseId));
    final membersAsync = ref.watch(houseMembersProvider(houseId));

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(houseMembersProvider(houseId));
          await ref.read(houseMembersProvider(houseId).future);
        },
        child: membersAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(houseMembersProvider(houseId)),
          ),
          data: (members) {
            final myRole = houseAsync.value?.myRole ?? HouseRole.member;
            final active = members.where((m) => m.isActive).toList();
            if (active.isEmpty) {
              return const EmptyView(
                icon: Icons.people_outline_rounded,
                title: 'No active members',
                message: 'Share the invite code to add housemates.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: active.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _MemberRow(
                member: active[index],
                isCurrentOwner: myRole == HouseRole.owner,
                houseId: houseId,
                onKick: myRole == HouseRole.owner && !active[index].isOwner
                    ? () => _kick(context, ref, active[index])
                    : null,
                onTransfer: myRole == HouseRole.owner && !active[index].isOwner
                    ? () => _transfer(context, ref, active[index])
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _kick(
    BuildContext context,
    WidgetRef ref,
    HouseMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          '${member.displayName} will be removed from this house.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(houseRepositoryProvider)
          .kickMember(houseId: houseId, memberId: member.userId);
      refreshHouseState(ref, houseId: houseId);
      if (context.mounted) {
        showAppMessage(context, '${member.displayName} removed.');
      }
    } catch (error) {
      if (context.mounted) showAppMessage(context, error.toString(), error: true);
    }
  }

  Future<void> _transfer(
    BuildContext context,
    WidgetRef ref,
    HouseMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer ownership?'),
        content: Text(
          'You will become a regular member and ${member.displayName} will become the new owner. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(houseRepositoryProvider).transferOwnership(
        houseId: houseId,
        newOwnerId: member.userId,
      );
      refreshHouseState(ref, houseId: houseId);
      if (context.mounted) {
        showAppMessage(context, 'Ownership transferred to ${member.displayName}.');
      }
    } catch (error) {
      if (context.mounted) showAppMessage(context, error.toString(), error: true);
    }
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isCurrentOwner,
    required this.houseId,
    required this.onKick,
    required this.onTransfer,
  });

  final HouseMember member;
  final bool isCurrentOwner;
  final String houseId;
  final VoidCallback? onKick;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
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
      title: Text(member.displayName),
      subtitle: Text(member.role.label),
      trailing: onKick != null || onTransfer != null
          ? PopupMenuButton<_MemberAction>(
              onSelected: (action) {
                if (action == _MemberAction.kick) onKick?.call();
                if (action == _MemberAction.transfer) onTransfer?.call();
              },
              itemBuilder: (_) => [
                if (onTransfer != null)
                  const PopupMenuItem(
                    value: _MemberAction.transfer,
                    child: Text('Transfer ownership'),
                  ),
                if (onKick != null)
                  const PopupMenuItem(
                    value: _MemberAction.kick,
                    child: Text(
                      'Remove from house',
                      style: TextStyle(color: AppTheme.red),
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}

enum _MemberAction { kick, transfer }
