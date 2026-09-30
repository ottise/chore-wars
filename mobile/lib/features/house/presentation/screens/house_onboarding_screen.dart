import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Entry point shown to a new user who has no house yet, or when adding a new house.
/// Lets the user choose to create a new house or join an existing one.
class HouseOnboardingScreen extends StatelessWidget {
  const HouseOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a house'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Set up your household',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Start fresh or join an existing house with an invite code.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              _OptionCard(
                icon: Icons.add_home_rounded,
                title: 'Create a house',
                description:
                    'You\'ll become the owner and can invite housemates.',
                accentColor: AppTheme.purple,
                onTap: () => context.push('/houses/new'),
              ),
              const SizedBox(height: 16),
              _OptionCard(
                icon: Icons.group_add_rounded,
                title: 'Join a house',
                description:
                    'Enter an invite code shared by your housemate.',
                accentColor: AppTheme.green,
                onTap: () => context.push('/houses/join'),
              ),
              const SizedBox(height: 16),
              _OptionCard(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scan QR code',
                description: 'Scan the QR code shown by an existing member.',
                accentColor: AppTheme.orange,
                onTap: () => context.push('/houses/qr-join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}
