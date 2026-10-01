import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: const Text('House settings')),
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
        ),
      ),
    );
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
  });

  final House house;
  final String houseId;
  final bool leavingHouse;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        _SectionHeader('House info'),
        ListTile(
          leading: const Icon(Icons.home_work_outlined),
          title: const Text('Name'),
          subtitle: Text(house.name),
        ),
        ListTile(
          leading: const Icon(Icons.calendar_today_outlined),
          title: const Text('Created'),
          subtitle: Text(
            '${house.createdAt.day}/${house.createdAt.month}/${house.createdAt.year}',
          ),
        ),
        const Divider(),
        _SectionHeader('Invite'),
        ListTile(
          leading: const Icon(Icons.key_rounded, color: AppTheme.purple),
          title: const Text('Invite code'),
          subtitle: Text(
            house.inviteCode,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontSize: 18,
            ),
          ),
          trailing: IconButton(
            tooltip: 'Copy code',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: house.inviteCode));
              showAppMessage(context, 'Invite code copied!');
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.qr_code_rounded, color: AppTheme.purple),
          title: const Text('Show QR code'),
          onTap: () => context.push('/houses/$houseId/qr-invite', extra: house),
        ),
        const Divider(),
        if (house.myRole == HouseRole.owner) ...[
          _SectionHeader('Members'),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Manage members'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/houses/$houseId/members'),
          ),
          const Divider(),
        ],
        
        _SectionHeader('Danger zone'),
        ListTile(
          leading: leavingHouse
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.exit_to_app_rounded, color: AppTheme.red),
          title: const Text(
            'Leave house',
            style: TextStyle(color: AppTheme.red),
          ),
          onTap: leavingHouse ? null : onLeave,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.8,
      ),
    ),
  );
}
