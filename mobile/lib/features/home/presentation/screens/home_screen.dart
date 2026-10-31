import '../../../../core/utils/vietnam_time.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/home_dashboard.dart';
import '../providers/home_dashboard_provider.dart';
import '../../../house/presentation/providers/current_house_provider.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houseId = ref.watch(currentHouseProvider);
    if (houseId == null || houseId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chore Wars'),
          actions: const [NotificationBell(), SizedBox(width: 8)],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyState(
                message: 'Join a house to see your dashboard.',
                icon: Icons.home_work_outlined,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/houses'),
                icon: const Icon(Icons.other_houses_outlined),
                label: const Text('View My Houses'),
              ),
            ],
          ),
        ),
      );
    }

    final dashboard = ref.watch(homeDashboardProvider(houseId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chore Wars'),
        actions: [
          NotificationBell(houseId: houseId),
          const SizedBox(width: 8),
        ],
      ),
      body: dashboard.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(homeDashboardProvider(houseId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(homeDashboardProvider(houseId).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                _greeting(data.userDisplayName),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'House: ${data.houseName}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              _KarmaCard(data: data),
              if (data.seasonId == null && data.isOwner) ...[
                const SizedBox(height: 16),
                Center(
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        context.push('/houses/${data.houseId}/seasons/new'),
                    icon: const Icon(Icons.add_task_outlined),
                    label: const Text('Start new season'),
                  ),
                ),
              ],
              if (data.seasonStatus == 1) ...[
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.tertiaryFixed,
                  child: ListTile(
                    leading: Icon(
                      data.currentUserConfirmationStatus == 1
                          ? Icons.hourglass_top_outlined
                          : Icons.rate_review_outlined,
                    ),
                    title: Text(
                      data.currentUserConfirmationStatus == 1
                          ? 'You confirmed this schedule'
                          : 'Schedule awaiting your confirmation',
                    ),
                    subtitle: Text(
                      data.currentUserConfirmationStatus == 1
                          ? 'Waiting for the other members '
                                '(${data.confirmedCount}/${data.requiredConfirmationCount} confirmed)'
                          : 'Tap to review and confirm the generated schedule',
                    ),
                    trailing: const Icon(Icons.chevron_right_outlined),
                    onTap: () => context.push(
                      '/houses/${data.houseId}/seasons/${data.seasonId}/review',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _SectionHeader(
                title: "Today's chores",
                action: data.chores.isEmpty
                    ? null
                    : () => context.push('/chores'),
              ),
              const SizedBox(height: 8),
              if (data.chores.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: EmptyState(
                    message: 'No chores today 🎉',
                    icon: Icons.check_circle_outline,
                  ),
                )
              else
                ...data.chores
                    .take(3)
                    .map(
                      (chore) =>
                          _ChoreTile(chore: chore, houseId: data.houseId),
                    ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Active bounties',
                action: () => context.push(
                  '/bounties?houseId=${Uri.encodeComponent(data.houseId)}',
                ),
              ),
              const SizedBox(height: 8),
              if (data.bounties.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: EmptyState(
                    message: 'No active bounties.',
                    icon: Icons.volunteer_activism_outlined,
                  ),
                )
              else
                ...data.bounties
                    .take(3)
                    .map(
                      (bounty) => _BountyTile(
                        amount: bounty.amount,
                        onTap: () => context.push(
                          '/bounties/${bounty.id}?houseId=${Uri.encodeComponent(data.houseId)}',
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(String displayName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return displayName.isEmpty ? '$greeting!' : '$greeting, $displayName!';
  }
}

class _KarmaCard extends StatelessWidget {
  final HomeDashboard data;

  const _KarmaCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(
          '/karma-history?houseId=${Uri.encodeComponent(data.houseId)}',
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                child: Icon(
                  Icons.bolt_outlined,
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Karma', style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    '${data.karma}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    data.rank == null
                        ? 'Rank unavailable'
                        : 'Rank #${data.rank}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? action;

  const _SectionHeader({required this.title, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (action != null)
          IconButton(
            tooltip: 'View all',
            onPressed: action,
            icon: const Icon(Icons.arrow_forward_outlined),
          ),
      ],
    );
  }
}

class _ChoreTile extends StatelessWidget {
  final DashboardChore chore;

  final String houseId;
  const _ChoreTile({required this.chore, required this.houseId});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: Text(chore.name),
        subtitle: Text(
          'Due ${DateFormat('dd MMM yyyy HH:mm').format(vietnamTime(chore.dueDate))} Vietnam time (UTC+7)',
        ),
        trailing: const Icon(Icons.chevron_right_outlined),
        onTap: () => context.push('/houses/$houseId/chores/${chore.id}'),
      ),
    );
  }
}

class _BountyTile extends StatelessWidget {
  final double amount;
  final VoidCallback onTap;

  const _BountyTile({required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.volunteer_activism_outlined),
        title: Text(
          NumberFormat.currency(
            locale: 'en_US',
            symbol: '₫',
            decimalDigits: 0,
          ).format(amount),
        ),
        subtitle: const Text('Active bounty'),
        trailing: const Icon(Icons.chevron_right_outlined),
        onTap: onTap,
      ),
    );
  }
}
