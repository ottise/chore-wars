import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class UiPreviewScreen extends StatelessWidget {
  const UiPreviewScreen({super.key});

  static const _houseId = AppConstants.previewHouseId;
  static const _seasonId = AppConstants.previewSeasonId;

  @override
  Widget build(BuildContext context) {
    final choreItems = [
      _PreviewItem(
        title: 'Chore list',
        description: 'Today, upcoming, and overdue assignments',
        icon: Icons.checklist_rounded,
        route: '/houses/$_houseId/chores',
      ),
      _PreviewItem(
        title: 'Create chore',
        description: 'Create a recurring or bonus routine',
        icon: Icons.add_task_rounded,
        route: '/houses/$_houseId/chores/new',
      ),
      _PreviewItem(
        title: 'Edit / delete',
        description: 'Change the sample dishes routine',
        icon: Icons.edit_note_rounded,
        route:
            '/houses/$_houseId/chores/templates/${AppConstants.previewChoreId}/edit',
      ),
      _PreviewItem(
        title: 'Chore detail',
        description: 'Complete or skip an assigned chore',
        icon: Icons.cleaning_services_rounded,
        route: '/houses/$_houseId/chores/${AppConstants.previewOccurrenceId}',
      ),
    ];
    final progressItems = [
      _PreviewItem(
        title: 'Leaderboard',
        description: 'Current season house standings',
        icon: Icons.emoji_events_rounded,
        route: '/houses/$_houseId/seasons/$_seasonId/leaderboard',
      ),
      _PreviewItem(
        title: 'Karma',
        description: 'Balance and point breakdown',
        icon: Icons.bolt_rounded,
        route: '/houses/$_houseId/karma',
      ),
      _PreviewItem(
        title: 'Karma history',
        description: 'Earnings, bonuses, and penalties',
        icon: Icons.history_rounded,
        route: '/houses/$_houseId/karma/history',
      ),
      _PreviewItem(
        title: 'Achievements',
        description: 'Unlocked milestones and future goals',
        icon: Icons.workspace_premium_rounded,
        route: '/houses/$_houseId/achievements',
      ),
      _PreviewItem(
        title: 'Season reward',
        description: 'Claim and review the winner reward',
        icon: Icons.card_giftcard_rounded,
        route: '/houses/$_houseId/seasons/$_seasonId/rewards',
      ),
      _PreviewItem(
        title: 'Use chore pass',
        description: 'Choose an assignment to pass',
        icon: Icons.confirmation_number_rounded,
        route:
            '/houses/$_houseId/seasons/$_seasonId/chore-pass/${AppConstants.previewRedemptionId}',
      ),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(onStart: () => context.push(choreItems.first.route)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _Section(title: 'Chores', items: choreItems),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
            sliver: SliverToBoxAdapter(
              child: _Section(
                title: 'Progress & rewards',
                items: progressItems,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.purple,
    padding: const EdgeInsets.fromLTRB(24, 36, 24, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.sports_martial_arts_rounded, color: AppTheme.yellow),
            SizedBox(width: 10),
            Text(
              'Chore Wars',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Spacer(),
            _PreviewBadge(),
          ],
        ),
        const SizedBox(height: 42),
        Text(
          'Pick a screen.\nTry every interaction.',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(color: Colors.white, fontSize: 38, height: 1.06),
        ),
        const SizedBox(height: 14),
        const Text(
          'Sample household data is already loaded. Nothing here is sent to a server.',
          style: TextStyle(color: Color(0xFFE5E1FF), height: 1.45),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onStart,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.yellow,
            foregroundColor: AppTheme.ink,
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Open chore board'),
        ),
      ],
    ),
  );
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Text(
        'UI preview',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<_PreviewItem> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 520 ? 2 : 1;
          const gap = 12.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: _PreviewCard(item: item),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.item});

  final _PreviewItem item;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push(item.route),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.purple.withValues(alpha: 0.1),
              foregroundColor: AppTheme.purple,
              child: Icon(item.icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(item.description),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
          ],
        ),
      ),
    ),
  );
}

class _PreviewItem {
  const _PreviewItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;
}
