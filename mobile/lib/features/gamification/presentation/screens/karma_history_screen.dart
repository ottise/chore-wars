import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../providers/gamification_providers.dart';

class KarmaHistoryScreen extends ConsumerWidget {
  const KarmaHistoryScreen({required this.houseId, super.key});
  final String houseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(karmaHistoryProvider(houseId));
    return Scaffold(
      appBar: AppBar(title: const Text('Karma history')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(karmaHistoryProvider(houseId));
          await ref.read(karmaHistoryProvider(houseId).future);
        },
        child: history.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(karmaHistoryProvider(houseId)),
          ),
          data: (items) => items.isEmpty
              ? const EmptyView(
                  icon: Icons.history_rounded,
                  title: 'No Karma activity',
                  message: 'Completed chores and penalties will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final positive = item.amount >= 0;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              (positive ? AppTheme.green : AppTheme.red)
                                  .withValues(alpha: 0.12),
                          child: Icon(
                            positive
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: positive ? AppTheme.green : AppTheme.red,
                          ),
                        ),
                        title: Text(item.description),
                        subtitle: Text(
                          DateFormat('MMM d, yyyy · h:mm a')
                              .format(item.createdAt),
                        ),
                        trailing: Text(
                          '${positive ? '+' : ''}${item.amount}',
                          style: TextStyle(
                            color: positive ? AppTheme.green : AppTheme.red,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
