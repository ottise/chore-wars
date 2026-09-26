import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../providers/gamification_providers.dart';

class KarmaScreen extends ConsumerWidget {
  const KarmaScreen({required this.houseId, super.key});
  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(karmaSummaryProvider(houseId));
    return Scaffold(
      appBar: AppBar(title: const Text('Karma')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(karmaSummaryProvider(houseId));
          await ref.read(karmaSummaryProvider(houseId).future);
        },
        child: summary.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(karmaSummaryProvider(houseId)),
          ),
          data: (karma) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.yellow,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Your Karma',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${karma.current}',
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(fontSize: 52, color: AppTheme.ink),
                    ),
                    if (karma.current < 0)
                      const Text(
                        'A fresh chore can turn this around.',
                        style: TextStyle(color: AppTheme.ink),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _KarmaRow(
                        label: 'Normal chores',
                        value: karma.normalChores,
                        icon: Icons.task_alt_rounded,
                      ),
                      const Divider(height: 28),
                      _KarmaRow(
                        label: 'Bonus',
                        value: karma.bonus,
                        icon: Icons.auto_awesome_rounded,
                      ),
                      const Divider(height: 28),
                      _KarmaRow(
                        label: 'Penalties',
                        value: karma.penalties,
                        icon: Icons.warning_amber_rounded,
                      ),
                      const Divider(height: 28),
                      _KarmaRow(
                        label: 'Current',
                        value: karma.current,
                        icon: Icons.bolt_rounded,
                        strong: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push('/houses/$houseId/karma/history'),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Karma history'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KarmaRow extends StatelessWidget {
  const _KarmaRow({
    required this.label,
    required this.value,
    required this.icon,
    this.strong = false,
  });
  final String label;
  final int value;
  final IconData icon;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: value < 0 ? AppTheme.red : AppTheme.purple),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
      Text(
        '${value > 0 ? '+' : ''}$value',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: strong ? 20 : 16,
          color: value < 0
              ? AppTheme.red
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );
}
