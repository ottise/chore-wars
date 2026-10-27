import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'supplies_ui.dart';

class SupplyChatCard extends StatelessWidget {
  const SupplyChatCard({required this.content, super.key});
  final String content;
  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(content) as Map);
    } catch (_) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Purchase update unavailable. Open Household Supplies to check your orders.',
        ),
      );
    }
    final house = Uri.encodeComponent(data['houseId']?.toString() ?? '');
    final id = Uri.encodeComponent(data['resourceId']?.toString() ?? '');
    final kind = data['resourceType'];
    final route = kind == 'SUPPLY_ORDER'
        ? '/houses/$house/supplies/orders/$id'
        : kind == 'INTERNAL_REPAYMENT'
        ? '/houses/$house/supplies/debts/$id'
        : '/houses/$house/supplies/schedules';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SupplySurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title']?.toString() ?? 'Household Supplies',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(data['message']?.toString() ?? ''),
            const SizedBox(height: 12),
            TextButton(
              onPressed: house.isEmpty || id.isEmpty
                  ? null
                  : () => context.go(route),
              child: Text(
                kind == 'SUPPLY_SCHEDULE' ? 'Review reminder' : 'View details',
              ),
            ),
            if (kind == 'SUPPLY_SCHEDULE')
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => context.go('/houses/$house/supplies'),
                    child: const Text('Order Supplies'),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.go('/houses/$house/chat/assistant'),
                    child: const Text('Ask AI'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
