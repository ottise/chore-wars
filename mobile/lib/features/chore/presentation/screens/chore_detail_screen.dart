import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../../domain/entities/chore_models.dart';
import '../providers/chore_providers.dart';
import '../../../../core/utils/api_error_message.dart';


class ChoreDetailScreen extends ConsumerStatefulWidget {
  const ChoreDetailScreen({
    required this.houseId,
    required this.occurrenceId,
    super.key,
  });

  final String houseId;
  final String occurrenceId;

  @override
  ConsumerState<ChoreDetailScreen> createState() => _ChoreDetailScreenState();
}

class _ChoreDetailScreenState extends ConsumerState<ChoreDetailScreen> {
  bool _mutating = false;

  @override
  Widget build(BuildContext context) {
    final key = (houseId: widget.houseId, occurrenceId: widget.occurrenceId);
    final detail = ref.watch(choreDetailProvider(key));
    return Scaffold(
      appBar: AppBar(title: const Text('Chore detail')),
      body: detail.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(choreDetailProvider(key)),
        ),
        data: (item) => _DetailBody(
          detail: item,
          busy: _mutating,
          onComplete: () => _complete(item),
          onSkip: () => _skip(item),
          onEdit: item.template == null
              ? null
              : () => context.push(
                  '/houses/${widget.houseId}/chores/templates/${item.template!.id}/edit',
                  extra: item.template,
                ),
        ),
      ),
    );
  }

  Future<void> _complete(ChoreDetail detail) async {
    setState(() => _mutating = true);
    try {
      await ref
          .read(choreRepositoryProvider)
          .completeChore(widget.occurrenceId);
      _refreshAffectedState();
      if (mounted) {
        showAppMessage(context, '+${detail.karmaPoints} Karma earned');
      }
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _skip(ChoreDetail detail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip this occurrence?'),
        content: const Text(
          'The server will check your permission and the household rules before skipping it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep chore'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _mutating = true);
    try {
      await ref.read(choreRepositoryProvider).skipChore(widget.occurrenceId);
      _refreshAffectedState();
      if (mounted) showAppMessage(context, 'Chore skipped');
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _refreshAffectedState() {
    refreshChoreState(ref, widget.houseId, occurrenceId: widget.occurrenceId);
    ref.invalidate(karmaSummaryProvider(widget.houseId));
    ref.invalidate(karmaHistoryProvider(widget.houseId));
    ref.invalidate(leaderboardProvider);
    ref.invalidate(achievementsProvider(widget.houseId));
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.busy,
    required this.onComplete,
    required this.onSkip,
    required this.onEdit,
  });

  final ChoreDetail detail;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final chore = detail.occurrence;
    final actionable =
        chore.status == ChoreStatus.assigned ||
        chore.status == ChoreStatus.overdue ||
        chore.status == ChoreStatus.criticalOverdue;
    final statusColor = switch (chore.status) {
      ChoreStatus.completed => AppTheme.green,
      ChoreStatus.overdue || ChoreStatus.criticalOverdue => AppTheme.red,
      ChoreStatus.skipped => AppTheme.muted,
      ChoreStatus.assigned => AppTheme.purple,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          color: AppTheme.purple,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  detail.template?.type == ChoreType.bonus
                      ? Icons.auto_awesome_rounded
                      : Icons.cleaning_services_rounded,
                  size: 34,
                  color: AppTheme.yellow,
                ),
                const SizedBox(height: 20),
                Text(
                  chore.choreName,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                if (detail.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail.description,
                    style: const TextStyle(
                      color: Color(0xFFE5E1FF),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Assigned to',
                  value: chore.assignedUserDisplayName,
                ),
                const Divider(height: 28),
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Due',
                  value: DateFormat('EEE, MMM d · h:mm a')
                      .format(chore.dueDate),
                ),
                const Divider(height: 28),
                _InfoRow(
                  icon: Icons.bolt_rounded,
                  label: 'Karma',
                  value: '+${detail.karmaPoints}',
                  valueColor: const Color(0xFF8A6100),
                ),
                const Divider(height: 28),
                _InfoRow(
                  icon: Icons.flag_outlined,
                  label: 'Status',
                  value: chore.status.label,
                  valueColor: statusColor,
                ),
              ],
            ),
          ),
        ),
        if (actionable) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: busy ? null : onComplete,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Complete chore'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : onSkip,
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('Skip chore'),
          ),
        ],
        if (onEdit != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit chore template'),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 22, color: AppTheme.muted),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(fontWeight: FontWeight.w800, color: valueColor),
        ),
      ),
    ],
  );
}
