import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../providers/custom_reward_providers.dart';
import '../providers/gamification_providers.dart';
import 'reward_form_screen.dart';

class RewardCatalogScreen extends ConsumerStatefulWidget {
  final String houseId;
  const RewardCatalogScreen({super.key, required this.houseId});
  @override
  ConsumerState<RewardCatalogScreen> createState() =>
      _RewardCatalogScreenState();
}

class _RewardCatalogScreenState extends ConsumerState<RewardCatalogScreen> {
  String? _busy;
  final Map<String, String> _requestIds = {};
  Future<void> _redeem(String id) async {
    setState(() => _busy = id);
    try {
      await ref
          .read(customRewardRepositoryProvider)
          .redeem(
            widget.houseId,
            id,
            _requestIds.putIfAbsent(id, () => const Uuid().v4()),
          );
      _requestIds.remove(id);
      ref.invalidate(customRewardsProvider(widget.houseId));
      ref.invalidate(gamificationRepositoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reward redeemed. Karma has been deducted.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Household rewards'),
      actions: [
        IconButton(
          tooltip: 'Create reward',
          onPressed: () =>
              context.push('/houses/${widget.houseId}/rewards/new'),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: ref
        .watch(customRewardsProvider(widget.houseId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: TextButton(
              onPressed: () =>
                  ref.invalidate(customRewardsProvider(widget.houseId)),
              child: Text('${apiErrorMessage(error)} · Retry'),
            ),
          ),
          data: (items) => items.isEmpty
              ? const Center(
                  child: Text('No rewards yet. Create one for your household.'),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final item in items)
                      Card(
                        child: ListTile(
                          leading: IconButton(
                            tooltip: 'Edit reward',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: _busy != null
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => RewardFormScreen(
                                        houseId: widget.houseId,
                                        reward: item,
                                      ),
                                    ),
                                  ),
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.description} · ${item.cost} Karma',
                          ),
                          trailing: FilledButton(
                            onPressed: !item.enabled || _busy != null
                                ? null
                                : () => _redeem(item.id),
                            child: Text(
                              _busy == item.id ? 'Redeeming…' : 'Redeem',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
  );
}
