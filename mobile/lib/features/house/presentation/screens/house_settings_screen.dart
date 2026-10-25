import '../../../../core/network/api_client.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/house_models.dart';
import '../providers/house_providers.dart';
import '../../../../core/utils/api_error_message.dart';

class HouseSettingsScreen extends ConsumerStatefulWidget {
  const HouseSettingsScreen({required this.houseId, super.key});

  final String houseId;

  @override
  ConsumerState<HouseSettingsScreen> createState() =>
      _HouseSettingsScreenState();
}

class _HouseSettingsScreenState extends ConsumerState<HouseSettingsScreen> {
  bool _leavingHouse = false;

  @override
  Widget build(BuildContext context) {
    final houseAsync = ref.watch(houseDetailProvider(widget.houseId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'House Settings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
      body: houseAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(houseDetailProvider(widget.houseId)),
        ),
        data: (house) => _SettingsBody(
          house: house,
          houseId: widget.houseId,
          leavingHouse: _leavingHouse,
          onLeave: () => _leaveHouse(house),
          onRotate: () => _adminAction('rotate-invite'),
          onArchive: () => _adminAction('archive'),
        ),
      ),
    );
  }

  Future<void> _adminAction(String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'archive'
              ? 'Archive household?'
              : 'Rotate invitation code?',
        ),
        content: Text(
          action == 'archive'
              ? 'History is preserved. Outstanding seasons, work and debts must be resolved first.'
              : 'The current invitation code and QR will stop working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _leavingHouse = true);
    try {
      await ref.read(dioProvider).post('/houses/${widget.houseId}/$action');
      refreshHouseState(ref, houseId: widget.houseId);
      if (mounted) showAppMessage(context, 'Household updated');
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _leavingHouse = false);
    }
  }

  Future<void> _leaveHouse(House house) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave house?'),
        content: Text(
          house.myRole == HouseRole.owner
              ? 'You are the owner. Transfer ownership before leaving, or the house will be left without an owner.'
              : 'You will lose access to "${house.name}" and all associated chores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _leavingHouse = true);
    try {
      await ref.read(houseRepositoryProvider).leaveHouse(widget.houseId);
      refreshHouseState(ref);
      if (mounted) context.go('/houses');
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _leavingHouse = false);
    }
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.house,
    required this.houseId,
    required this.leavingHouse,
    required this.onLeave,
    required this.onRotate,
    required this.onArchive,
  });

  final House house;
  final String houseId;
  final bool leavingHouse;
  final VoidCallback onLeave;
  final VoidCallback onRotate, onArchive;

  @override
  Widget build(BuildContext context) {
    final owner = house.myRole == HouseRole.owner;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.home_outlined,
                title: house.name,
                subtitle: 'Name',
              ),
              const Divider(height: 1, indent: 64),
              _SettingsRow(
                icon: Icons.calendar_month_outlined,
                title: DateFormat.yMMMd('en_US').format(house.createdAt),
                subtitle: 'Created',
              ),
            ],
          ),
        ),
        if (owner) ...[
          const _SectionHeader('Automation & Governance'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.sync_outlined,
                  title: 'System Recovery',
                  subtitle: 'Track failures & request retries',
                  onTap: () => context.push('/houses/$houseId/failed-events'),
                ),
                const Divider(height: 1, indent: 64),
                _SettingsRow(
                  icon: Icons.key_outlined,
                  title: 'Rotate Invitation Code',
                  subtitle: 'Replace the current invite link & QR',
                  onTap: leavingHouse ? null : onRotate,
                ),
              ],
            ),
          ),
        ],
        const _SectionHeader('Household Invitation'),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Icon(
                  Icons.key_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text(
                  'Invite Code',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                subtitle: Text(
                  house.inviteCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Copy code',
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: house.inviteCode));
                    showAppMessage(context, 'Invite code copied!');
                  },
                ),
              ),
              const Divider(height: 1, indent: 64),
              _SettingsRow(
                icon: Icons.qr_code_outlined,
                title: 'Show QR Code',
                onTap: () =>
                    context.push('/houses/$houseId/qr-invite', extra: house),
              ),
            ],
          ),
        ),
        const _SectionHeader('Membership & Permissions'),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.manage_accounts_outlined,
                title: owner
                    ? 'Transfer Ownership & Members'
                    : 'Household Members',
                subtitle: owner
                    ? 'Manage access & choose the next owner'
                    : 'View your household members',
                onTap: () => context.push('/houses/$houseId/members'),
              ),
              if (owner) ...[
                const Divider(height: 1, indent: 64),
                _SettingsRow(
                  icon: Icons.archive_outlined,
                  title: 'Archive Household',
                  subtitle: 'Preserve household history',
                  onTap: leavingHouse ? null : onArchive,
                ),
              ],
              const Divider(height: 1, indent: 64),
              _SettingsRow(
                icon: Icons.logout_outlined,
                title: leavingHouse ? 'Updating…' : 'Leave Household',
                subtitle: 'Revoke your access to this household',
                destructive: true,
                onTap: leavingHouse ? null : onLeave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = destructive ? colors.error : colors.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, size: 21, color: accent),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: destructive ? colors.error : colors.onSurface,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
      trailing: onTap == null
          ? null
          : Icon(
              Icons.chevron_right_outlined,
              size: 18,
              color: destructive ? colors.error : colors.onSurfaceVariant,
            ),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
