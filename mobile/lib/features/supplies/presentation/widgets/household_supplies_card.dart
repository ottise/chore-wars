import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/supplies_providers.dart';

import 'supplies_ui.dart';

class HouseholdSuppliesCard extends ConsumerWidget {
  const HouseholdSuppliesCard({required this.houseId, super.key});
  final String houseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => SupplySurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Household Supplies',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ref
            .watch(suppliersProvider)
            .when(
              loading: () => const Text('Loading supplier contact…'),
              error: (_, _) => const Text(
                'Supplier contact unavailable. Open supplies to retry.',
              ),
              data: (shops) => shops.isEmpty
                  ? const Text('No supplier available yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shops.first['name'].toString()),
                        Text(
                          (shops.first['phone']?.toString().trim() ?? '')
                                  .isEmpty
                              ? 'Contact number not available'
                              : shops.first['phone'].toString(),
                        ),
                      ],
                    ),
            ),
        const SizedBox(height: 8),
        const Text('Order essentials together and track who owes whom.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => context.push('/houses/$houseId/supplies'),
              icon: const Icon(Icons.shopping_basket_outlined),
              label: const Text('Order Supplies'),
            ),
            TextButton(
              onPressed: () =>
                  context.push('/houses/$houseId/chat/assistant', extra: null),
              child: const Text('Ask AI'),
            ),
            TextButton(
              onPressed: () => context.push('/houses/$houseId/supplies/debts'),
              child: const Text('Household Debts'),
            ),
          ],
        ),
      ],
    ),
  );
}
