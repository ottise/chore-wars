import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/chore_models.dart';

class ChoreCard extends StatelessWidget {
  const ChoreCard({
    required this.chore,
    required this.karma,
    required this.onTap,
    super.key,
  });

  final ChoreOccurrence chore;
  final int karma;
  final VoidCallback onTap;

  Color get _statusColor => switch (chore.status) {
    ChoreStatus.completed => AppTheme.green,
    ChoreStatus.overdue || ChoreStatus.criticalOverdue => AppTheme.red,
    ChoreStatus.skipped => AppTheme.muted,
    ChoreStatus.assigned => AppTheme.purple,
  };

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(chore.dueDate, DateTime.now());
    final due = isToday
        ? 'Today, ${DateFormat.jm().format(chore.dueDate)}'
        : DateFormat('EEE, MMM d · h:mm a').format(chore.dueDate);
    return Semantics(
      button: true,
      label: '${chore.choreName}, due $due, ${chore.status.label}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: _statusColor,
                  child: const SizedBox(width: 5),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chore.choreName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _KarmaPill(value: karma),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 17,
                              color: _statusColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(due)),
                            Text(
                              chore.status.label,
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KarmaPill extends StatelessWidget {
  const _KarmaPill({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppTheme.yellow.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        '+$value Karma',
        style: const TextStyle(
          color: Color(0xFF7A5700),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}
