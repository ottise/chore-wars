import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../home/presentation/providers/home_dashboard_provider.dart';
import '../../../payment/presentation/providers/payment_providers.dart';
import '../../domain/entities/bounty.dart';
import '../providers/bounty_providers.dart';

class BountyDetailScreen extends ConsumerWidget {
  final String? houseId;
  final String bountyId;

  const BountyDetailScreen({super.key, required this.houseId, required this.bountyId});

  Future<void> _accept(BuildContext context, WidgetRef ref, Bounty bounty) async {
    if (houseId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept this chore?'),
        content: Text(
          'You will receive ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(bounty.amount)}.',
        ),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => context.pop(true), child: const Text('CONFIRM')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(bountyRepositoryProvider).acceptBounty(
            houseId: houseId!,
            bountyId: bounty.id,
          );
      ref.invalidate(bountyBoardProvider(houseId!));
      ref.invalidate(homeDashboardProvider(houseId!));
      ref.invalidate(paymentListProvider(houseId!));
      if (context.mounted) context.pop();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (houseId == null || houseId!.isEmpty) {
      return const Scaffold(body: ErrorState(error: 'House is required.', onRetry: _noop));
    }
    final state = ref.watch(bountyDetailProvider((houseId: houseId!, bountyId: bountyId)));
    return Scaffold(
      appBar: AppBar(title: const Text('Bounty Detail')),
      body: state.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(bountyDetailProvider((houseId: houseId!, bountyId: bountyId))),
        ),
        data: (bounty) {
          final currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
          final isExpired = bounty.status == BountyStatus.expired;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(bounty.choreName, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              _DetailRow(label: 'Original assignee', value: bounty.postedByDisplayName),
              _DetailRow(label: 'Bounty', value: currency.format(bounty.amount)),
              _DetailRow(label: 'Due', value: DateFormat('dd/MM HH:mm').format(bounty.expiresAt)),
              if (isExpired) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bounty Expired', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text('This chore has been reassigned.'),
                        if (bounty.newAssigneeDisplayName != null)
                          _DetailRow(label: 'New assignee', value: bounty.newAssigneeDisplayName!),
                        if (bounty.forcedCompensationAmount != null)
                          _DetailRow(
                            label: 'Compensation',
                            value: currency.format(bounty.forcedCompensationAmount),
                          ),
                        const Text('Status: Pending'),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: bounty.status == BountyStatus.open
                      ? () => _accept(context, ref, bounty)
                      : null,
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('ACCEPT BOUNTY'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static void _noop() {}
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}