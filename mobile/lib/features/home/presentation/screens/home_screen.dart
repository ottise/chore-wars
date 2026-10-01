import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/home_dashboard.dart';
import '../providers/home_dashboard_provider.dart';

class HomeScreen extends ConsumerWidget {
  final String? houseId;

  const HomeScreen({super.key, this.houseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (houseId == null || houseId!.isEmpty) {
      return const EmptyState(
        message: 'Join a house to see your dashboard.',
        icon: Icons.home_work_outlined,
      );
    }

    final dashboard = ref.watch(homeDashboardProvider(houseId!));
    return dashboard.when(
      loading: () => const LoadingWidget(),
      error: (error, stackTrace) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(homeDashboardProvider(houseId!)),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () => ref.refresh(homeDashboardProvider(houseId!).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(_greeting(data.userDisplayName), style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('House: ${data.houseName}', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            _KarmaCard(data: data),
            if (data.rank == null) ...[
              const SizedBox(height: 16),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push('/houses/${data.houseId}/seasons/new'),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Start new season'),
                ),
              ),
            ],
            if (data.seasonStatus == 1) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.rate_review_rounded),
                  title: const Text('Schedule awaiting your confirmation'),
                  subtitle: const Text('Tap to review and confirm the generated schedule'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/houses/${data.houseId}/seasons/${data.seasonId}/review',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _SectionHeader(
              title: "Today's chores",
              action: data.chores.isEmpty ? null : () => context.push('/chores'),
            ),
            const SizedBox(height: 8),
            if (data.chores.isEmpty)
              const SizedBox(height: 120, child: EmptyState(message: 'No chores today 🎉', icon: Icons.check_circle_outline))
            else
              ...data.chores.take(3).map((chore) => _ChoreTile(chore: chore)),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Active bounties',
              action: () => context.push('/bounties?houseId=${Uri.encodeComponent(data.houseId)}'),
            ),
            const SizedBox(height: 8),
            if (data.bounties.isEmpty)
              const SizedBox(height: 100, child: EmptyState(message: 'No active bounties.', icon: Icons.volunteer_activism_outlined))
            else
              ...data.bounties.take(3).map(
                    (bounty) => _BountyTile(
                      amount: bounty.amount,
                      onTap: () => context.push('/bounties/${bounty.id}?houseId=${Uri.encodeComponent(data.houseId)}'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _greeting(String displayName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
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
        onTap: () => context.push('/karma-history?houseId=${Uri.encodeComponent(data.houseId)}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                child: Icon(Icons.bolt, color: Theme.of(context).colorScheme.onSecondary),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Karma', style: Theme.of(context).textTheme.bodyMedium),
                  Text('${data.karma}', style: Theme.of(context).textTheme.headlineMedium),
                  Text(data.rank == null ? 'Rank unavailable' : 'Rank #${data.rank}', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right),
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
        if (action != null) IconButton(tooltip: 'View all', onPressed: action, icon: const Icon(Icons.arrow_forward)),
      ],
    );
  }
}

class _ChoreTile extends StatelessWidget {
  final DashboardChore chore;

  const _ChoreTile({required this.chore});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: Text(chore.name),
        subtitle: Text('Due ${DateFormat('HH:mm').format(chore.dueDate)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(
          '/chores/${chore.id}?name=${Uri.encodeComponent(chore.name)}&due=${Uri.encodeComponent(DateFormat('HH:mm').format(chore.dueDate))}&status=${Uri.encodeComponent(chore.status)}',
        ),
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
        title: Text(NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(amount)),
        subtitle: const Text('Active bounty'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}