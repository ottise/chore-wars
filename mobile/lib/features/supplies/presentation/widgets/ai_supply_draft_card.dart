import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/supplies_repository.dart';
import 'supplies_ui.dart';

class AiSupplyDraftCard extends StatelessWidget {
  const AiSupplyDraftCard({
    required this.houseId,
    required this.candidate,
    super.key,
  });
  final String houseId;
  final SupplyData candidate;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SupplySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review supplies',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Check the quantities, then send your order by email. Nothing has been sent or paid yet.',
          ),
          if ((candidate['lines'] as List? ?? []).isNotEmpty)
            FilledButton(
              onPressed: () =>
                  context.push('/houses/$houseId/orders', extra: candidate),
              child: const Text('Review AI selection'),
            ),
          if (candidate['reminder'] is Map)
            TextButton(
              onPressed: () => context.push(
                '/houses/$houseId/supplies/schedules',
                extra: Map<String, dynamic>.from(candidate['reminder'] as Map),
              ),
              child: const Text('Review group reminder'),
            ),
        ],
      ),
    ),
  );
}
