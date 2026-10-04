import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/app_states.dart';
import '../../domain/entities/bounty.dart';
import '../providers/bounty_providers.dart';

class BountyBoardScreen extends ConsumerWidget {
  final String? houseId;

  const BountyBoardScreen({super.key, required this.houseId});

  Future<void> _openCreateBounty(BuildContext context, WidgetRef ref) async {
    if (houseId == null || houseId!.isEmpty) return;

    try {
      final dio = ref.read(dioProvider);
      final seasonResponse = await dio.get('/houses/$houseId/seasons/current');
      final season = seasonResponse.data is Map
          ? Map<String, dynamic>.from(seasonResponse.data as Map)
          : <String, dynamic>{};
      final seasonId = season['id']?.toString();
      if (seasonId == null || seasonId.isEmpty) {
        if (context.mounted) {
          showAppMessage(
            context,
            'Create a season before posting a bounty.',
            error: true,
          );
        }
        return;
      }

      final occurrencesResponse = await dio.get(
        '/houses/$houseId/seasons/$seasonId/occurrences',
      );
      final occurrences = occurrencesResponse.data is List
          ? (occurrencesResponse.data as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where((item) => item['status']?.toString() != 'COMPLETED')
                .toList()
          : <Map<String, dynamic>>[];

      if (!context.mounted) return;
      if (occurrences.isEmpty) {
        showAppMessage(
          context,
          'No chore occurrences are available for a bounty.',
          error: true,
        );
        return;
      }

      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: occurrences.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final occurrence = occurrences[index];
              final dueDate = DateTime.tryParse(
                occurrence['dueDate']?.toString() ?? '',
              );
              return ListTile(
                title: Text(occurrence['choreName']?.toString() ?? 'Chore'),
                subtitle: Text(
                  dueDate == null
                      ? 'Due date unavailable'
                      : 'Due ${DateFormat('dd/MM HH:mm').format(dueDate.toLocal())}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, occurrence),
              );
            },
          ),
        ),
      );

      if (selected == null || !context.mounted) return;
      final occurrenceId = selected['id']?.toString();
      if (occurrenceId == null || occurrenceId.isEmpty) return;
      final dueDate = DateTime.tryParse(selected['dueDate']?.toString() ?? '');
      context.push(
        '/bounties/create?houseId=${Uri.encodeComponent(houseId!)}'
        '&occurrenceId=${Uri.encodeComponent(occurrenceId)}'
        '&choreName=${Uri.encodeComponent(selected['choreName']?.toString() ?? 'Chore')}'
        '&deadline=${Uri.encodeComponent(dueDate?.toLocal().toIso8601String() ?? '')}',
      );
    } catch (error) {
      if (context.mounted) {
        showAppMessage(context, apiErrorMessage(error), error: true);
      }
    }
  }

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
            onPressed: () => _openCreateBounty(context, ref),
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
    final currency = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
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
                    child: Text(
                      bounty.choreName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
