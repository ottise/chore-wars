import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_page_frame.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../home/presentation/providers/home_dashboard_provider.dart';
import '../../domain/entities/payment_obligation.dart';
import '../providers/payment_providers.dart';

class PaymentObligationsScreen extends ConsumerStatefulWidget {
  final String? houseId;

  const PaymentObligationsScreen({super.key, required this.houseId});

  @override
  ConsumerState<PaymentObligationsScreen> createState() =>
      _PaymentObligationsScreenState();
}

class _PaymentObligationsScreenState
    extends ConsumerState<PaymentObligationsScreen> {
  bool _history = false;
  bool _settling = false;
  String? get houseId => widget.houseId;
  bool _active(PaymentObligation payment) =>
      payment.status != PaymentStatus.paid &&
      payment.status != PaymentStatus.cancelled;
  @override
  Widget build(BuildContext context) => AppPageFrame(builder: _buildScreen);

  Widget _buildScreen(BuildContext context) {
    if (houseId == null || houseId!.isEmpty) {
      return const Scaffold(
        body: EmptyState(
          message: 'Select a house to view payment obligations.',
        ),
      );
    }

    final payments = ref.watch(paymentListProvider(houseId!));
    return Scaffold(
      appBar: AppPageBar(title: 'Payment Obligations', centerTitle: true),
      body: payments.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(paymentListProvider(houseId!)),
        ),
        data: (items) {
          final active = items.where(_active).toList();
          final history = items.where((item) => !_active(item)).toList();
          final visible = _history ? history : active;
          final userId = ref.watch(userProfileProvider).asData?.value.id;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(paymentListProvider(houseId!).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SegmentedButton<bool>(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      side: const WidgetStatePropertyAll(BorderSide.none),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text('Active (${active.length})'),
                      ),
                      const ButtonSegment(
                        value: true,
                        label: Text('Settled History'),
                      ),
                    ],
                    selected: {_history},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        setState(() => _history = value.first),
                  ),
                ),
                const SizedBox(height: 20),
                if (visible.isEmpty)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            Theme.of(context).colorScheme.primaryFixed
                                .withValues(alpha: .5),
                            Theme.of(context)
                                .colorScheme
                                .surfaceContainerLowest,
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: Stack(
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryFixed,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    _history
                                        ? Icons.history_outlined
                                        : Icons.account_balance_wallet_outlined,
                                    size: 30,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                                if (!_history)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLowest,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_outlined,
                                        color: Color(0xFF00A880),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _history
                                ? 'No Settled Payments Yet'
                                : 'All Settled Up!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _history
                                ? 'Payments confirmed as received will appear here.'
                                : 'You have no active bounty payment obligations in this household.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final payment in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PaymentCard(
                      payment: payment,
                      onSettle:
                          !_settling &&
                              payment.status == PaymentStatus.pending &&
                              payment.creditorUserId == userId
                          ? () => _settle(context, ref, payment)
                          : null,
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  'Payments are confirmed manually by the recipient after the money is received.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _settle(
    BuildContext context,
    WidgetRef ref,
    PaymentObligation payment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm money received?'),
        content: const Text(
          'Confirm only after you have received the money. This is a manual confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _settling = true);
    try {
      await ref
          .read(paymentRepositoryProvider)
          .settlePayment(houseId: houseId!, paymentId: payment.id);
      ref.invalidate(paymentListProvider(houseId!));
      ref.invalidate(homeDashboardProvider(houseId!));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _settling = false);
    }
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentObligation payment;
  final VoidCallback? onSettle;

  const _PaymentCard({required this.payment, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₫',
      decimalDigits: 0,
    );
    final reason = switch (payment.reason) {
      PaymentReason.forcedReassignment => 'Forced reassignment',
      PaymentReason.bountyPayment => 'Bounty',
      PaymentReason.penalty => 'Penalty',
      PaymentReason.other => 'Other',
      PaymentReason.unknown => 'Unknown',
    };
    final status = switch (payment.status) {
      PaymentStatus.pending => 'Pending',
      PaymentStatus.paid => 'Recipient confirmed receipt',
      PaymentStatus.disputed => 'Disputed',
      PaymentStatus.cancelled => 'Cancelled',
      PaymentStatus.unknown => 'Unknown',
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.payments_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              currency.format(payment.amount),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text('From: ${payment.debtorDisplayName}'),
            const SizedBox(height: 6),
            Text('To: ${payment.creditorDisplayName}'),
            const SizedBox(height: 6),
            Text('Reason: $reason'),
            const SizedBox(height: 6),
            Text('Status: $status'),
            if (onSettle != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSettle,
                  child: const Text('Confirm Received'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
