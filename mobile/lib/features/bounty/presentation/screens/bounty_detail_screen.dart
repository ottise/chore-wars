import '../../../../core/utils/vietnam_time.dart';
import '../../../chore/presentation/providers/chore_providers.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../house/presentation/providers/house_providers.dart';

import 'package:flutter/material.dart';

import '../../../supplies/presentation/providers/supplies_providers.dart';
import '../../../payment/presentation/providers/payment_history_provider.dart';
import '../../../house/presentation/providers/household_summary_provider.dart';

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
import '../../../ai/presentation/ai_observed_view.dart';

class BountyDetailScreen extends ConsumerStatefulWidget {
  final String? houseId;
  final String bountyId;

  const BountyDetailScreen({
    super.key,
    required this.houseId,
    required this.bountyId,
  });

  @override
  ConsumerState<BountyDetailScreen> createState() => _BountyDetailScreenState();
}

class _BountyDetailScreenState extends ConsumerState<BountyDetailScreen> {
  bool _busy = false;
  String? get houseId => widget.houseId;
  String get bountyId => widget.bountyId;
  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/houses/$houseId/bounties');
    }
  }

  Future<void> _cancel(Bounty bounty) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          bounty.status == BountyStatus.claimed
              ? 'Request / approve cancellation?'
              : 'Withdraw bounty?',
        ),
        content: Text(
          bounty.status == BountyStatus.claimed
              ? 'Both participants must agree. On approval, the chore returns to its original assignee and the unfinished commitment is cancelled.'
              : 'This listing will close. The chore remains yours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep bounty'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dioProvider)
          .post('/houses/$houseId/bounties/${bounty.id}/cancel');
      ref.invalidate(
        bountyDetailProvider((houseId: houseId!, bountyId: bountyId)),
      );
      ref.invalidate(bountyBoardProvider(houseId!));
      refreshChoreState(ref, houseId!, occurrenceId: bounty.choreOccurrenceId);
      ref.invalidate(purchaseDebtsProvider(houseId!));
      ref.invalidate(householdSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cancellation saved. Claimed work changes only after both participants agree.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    Bounty bounty,
  ) async {
    if (houseId == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept this chore?'),
        content: Text(
          'You will receive ${NumberFormat.currency(locale: 'en_US', symbol: '₫', decimalDigits: 0).format(bounty.amount)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(bountyRepositoryProvider)
          .acceptBounty(houseId: houseId!, bountyId: bounty.id);
      ref.invalidate(bountyBoardProvider(houseId!));
      refreshChoreState(ref, houseId!, occurrenceId: bounty.choreOccurrenceId);
      ref.invalidate(purchaseDebtsProvider(houseId!));
      ref.invalidate(householdSummaryProvider);
      ref.invalidate(homeDashboardProvider(houseId!));
      ref.invalidate(paymentListProvider(houseId!));
      ref.invalidate(purchaseDebtsProvider(houseId!));
      ref.invalidate(paymentHistoryProvider);
      ref.invalidate(householdSummaryProvider);
      refreshHouseState(ref, houseId: houseId!);
      ref.invalidate(
        bountyDetailProvider((houseId: houseId!, bountyId: bountyId)),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bounty accepted. Find it in Chore → Bonus.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (houseId == null || houseId!.isEmpty) {
      return const Scaffold(
        body: ErrorState(error: 'House is required.', onRetry: _noop),
      );
    }
    final state = ref.watch(
      bountyDetailProvider((houseId: houseId!, bountyId: bountyId)),
    );
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _back(context)),
        title: const Text('Bounty Detail'),
      ),
      body: state.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(
            bountyDetailProvider((houseId: houseId!, bountyId: bountyId)),
          ),
        ),
        data: (bounty) {
          final currency = NumberFormat.currency(
            locale: 'en_US',
            symbol: '₫',
            decimalDigits: 0,
          );
          final isExpired = bounty.status == BountyStatus.expired;
          return AiObservedView(
            house: houseId!,
            entity: bountyId,
            kind: AiObservedView.bountyOpened,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  bounty.choreName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                _DetailRow(
                  label: 'Original assignee',
                  value: bounty.postedByDisplayName,
                ),
                _DetailRow(
                  label: 'Bounty',
                  value: currency.format(bounty.amount),
                ),
                _DetailRow(
                  label: 'Chore deadline (Vietnam)',
                  value: DateFormat('dd/MM/yyyy HH:mm')
                      .format(vietnamTime(bounty.expiresAt)),
                ),
                if (bounty.status == BountyStatus.claimed &&
                    (bounty.postedByUserId ==
                            ref.watch(userProfileProvider).asData?.value.id ||
                        (bounty.claimedByUserId ?? bounty.assignedUserId) ==
                            ref
                                .watch(userProfileProvider)
                                .asData
                                ?.value
                                .id)) ...[
                  if (bounty.cancellationRequestedByUserId != null)
                    Text(
                      bounty.cancellationRequestedByUserId ==
                              ref.watch(userProfileProvider).asData?.value.id
                          ? 'Cancellation requested · Waiting for the other participant.'
                          : 'The other participant requests cancellation.',
                    ),
                  OutlinedButton(
                    onPressed:
                        _busy ||
                            bounty.cancellationRequestedByUserId ==
                                ref.watch(userProfileProvider).asData?.value.id
                        ? null
                        : () => _cancel(bounty),
                    child: Text(
                      bounty.cancellationRequestedByUserId == null
                          ? 'Request cancellation'
                          : 'Approve cancellation',
                    ),
                  ),
                ],
                if (isExpired) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bounty Expired',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bounty.forcedCompensationAmount != null
                                ? 'A forced compensation was recorded. Check obligations for its current status.'
                                : 'Bounty expired. The household may need to resolve this assignment.',
                          ),
                          if (bounty.newAssigneeDisplayName != null)
                            _DetailRow(
                              label: 'New assignee',
                              value: bounty.newAssigneeDisplayName!,
                            ),
                          if (bounty.forcedCompensationAmount != null)
                            _DetailRow(
                              label: 'Compensation',
                              value: currency.format(
                                bounty.forcedCompensationAmount,
                              ),
                            ),
                          TextButton(
                            onPressed: () =>
                                context.push('/houses/$houseId/account/debts'),
                            child: const Text('View My Debts'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                TextButton.icon(
                  onPressed: () => context.push(
                    '/houses/$houseId/chores/${bounty.choreOccurrenceId}',
                  ),
                  icon: const Icon(Icons.checklist),
                  label: const Text('Open chore & photo evidence'),
                ),
                if (bounty.status == BountyStatus.open &&
                    bounty.postedByUserId ==
                        ref.watch(userProfileProvider).asData?.value.id)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _cancel(bounty),
                    child: const Text('Withdraw bounty'),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        !_busy &&
                            bounty.status == BountyStatus.open &&
                            bounty.postedByUserId !=
                                ref.watch(userProfileProvider).asData?.value.id
                        ? () => _accept(context, ref, bounty)
                        : null,
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: const Text('ACCEPT BOUNTY'),
                  ),
                ),
              ],
            ),
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
