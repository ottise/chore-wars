import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/utils/api_error_message.dart';


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          profileAsync.whenData(
            (profile) => TextButton.icon(
              onPressed: () => context.push('/profile/edit', extra: profile),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ).value ??
              const SizedBox.shrink(),
        ],
      ),
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
                child: Text(
                  profile.displayName.isNotEmpty
                      ? profile.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.purple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                profile.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Center(
              child: Text(
                profile.email,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 40),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Display name'),
              subtitle: Text(profile.displayName),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(profile.email),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 1),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout_rounded, color: AppTheme.red),
              label: const Text(
                'Sign out',
                style: TextStyle(color: AppTheme.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.red),
                minimumSize: const Size.fromHeight(50),
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
        content: const Text('You will need to sign in again to access your houses.'),
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
      if (context.mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    }
  }
}
