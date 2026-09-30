import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/bounty.dart';
import '../providers/bounty_providers.dart';

class BountyBoardScreen extends ConsumerWidget {
  final String? houseId;

  const BountyBoardScreen({super.key, required this.houseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (houseId == null || houseId!.isEmpty) {
      return const Scaffold(
        body: EmptyState(message: 'Select a house to view open bounties.'),
      );
    }

    final bounties = ref.watch(bountyBoardProvider(houseId!));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bounty Board'),
        actions: [
          IconButton(
            tooltip: 'Create bounty',
            onPressed: () => context.push(
              '/bounties/create?houseId=${Uri.encodeComponent(houseId!)}',
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: bounties.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(bountyBoardProvider(houseId!)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              message: 'No open bounties right now.',
              icon: Icons.volunteer_activism_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(bountyBoardProvider(houseId!).future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _BountyCard(
                bounty: items[index],
                onTap: () => context.push(
                  '/bounties/${items[index].id}?houseId=${Uri.encodeComponent(houseId!)}',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BountyCard extends StatelessWidget {
  final Bounty bounty;
  final VoidCallback onTap;

  const _BountyCard({required this.bounty, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final date = DateFormat('dd/MM HH:mm').format(bounty.expiresAt);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cleaning_services_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(bounty.choreName, style: Theme.of(context).textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Posted by: ${bounty.postedByDisplayName}'),
              const SizedBox(height: 8),
              Text('Bounty: ${currency.format(bounty.amount)}'),
              const SizedBox(height: 8),
              Text('Due: $date'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  child: const Text('ACCEPT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}