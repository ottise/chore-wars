import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';
import '../providers/house_providers.dart';

final unresolvedChoresProvider = FutureProvider.autoDispose
    .family<List<dynamic>, String>((ref, houseId) async {
      final response = await ref
          .watch(dioProvider)
          .get('/houses/$houseId/unresolved-chores');
      return List.from(response.data as List);
    });

class UnresolvedChoresScreen extends ConsumerStatefulWidget {
  final String houseId;
  const UnresolvedChoresScreen({super.key, required this.houseId});
  @override
  ConsumerState<UnresolvedChoresScreen> createState() =>
      _UnresolvedChoresScreenState();
}

class _UnresolvedChoresScreenState
    extends ConsumerState<UnresolvedChoresScreen> {
  bool _busy = false;
  Future<void> _take(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take responsibility?'),
        content: const Text(
          'You will have 24 hours to finish. This action does not create another compensation payment. Any unearned forced compensation for the prior assignee is cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Take chore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(dioProvider).post('/occurrences/$id/take-responsibility');
      ref.invalidate(unresolvedChoresProvider(widget.houseId));
      refreshHouseState(ref, houseId: widget.houseId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chores needing resolution')),
    body: ref
        .watch(unresolvedChoresProvider(widget.houseId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: TextButton(
              onPressed: () =>
                  ref.invalidate(unresolvedChoresProvider(widget.houseId)),
              child: Text('${apiErrorMessage(error)} · Retry'),
            ),
          ),
          data: (items) => items.isEmpty
              ? const Center(child: Text('No unresolved chores.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (final item in items)
                      Card(
                        child: ListTile(
                          title: Text(item['choreName'].toString()),
                          subtitle: Text(
                            item['assignedUserDisplayName']?.toString() ??
                                'Unassigned',
                          ),
                          onTap: () => context.push(
                            '/houses/${widget.houseId}/chores/${item['id']}',
                          ),
                          trailing: TextButton(
                            onPressed: _busy
                                ? null
                                : () => _take(item['id'].toString()),
                            child: const Text('Take over'),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
  );
}
