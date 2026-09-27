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

class PaymentObligationsScreen extends ConsumerWidget {
  final String? houseId;

  const PaymentObligationsScreen({super.key, required this.houseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (houseId == null || houseId!.isEmpty) {
      return const Scaffold(body: EmptyState(message: 'Select a house to view payment obligations.'));
    }

    final payments = ref.watch(paymentListProvider(houseId!));
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Obligations')),
      body: payments.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(paymentListProvider(houseId!)),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(message: 'No payment obligations.', icon: Icons.payments_outlined)
            : RefreshIndicator(
                onRefresh: () => ref.refresh(paymentListProvider(houseId!).future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _PaymentCard(
                    payment: items[index],
                    onSettle: items[index].status == PaymentStatus.pending
                        ? () => _settle(context, ref, items[index])
                        : null,
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _settle(BuildContext context, WidgetRef ref, PaymentObligation payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as settled?'),
        content: const Text('This will mark the payment obligation as paid.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRM')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(paymentRepositoryProvider).settlePayment(
            houseId: houseId!,
            paymentId: payment.id,
          );
      ref.invalidate(paymentListProvider(houseId!));
      ref.invalidate(homeDashboardProvider(houseId!));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    }
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentObligation payment;
  final VoidCallback? onSettle;

  const _PaymentCard({required this.payment, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final isForced = payment.reason == PaymentReason.forcedReassignment;
    final status = switch (payment.status) {
      PaymentStatus.pending => 'Pending',
      PaymentStatus.paid => 'Paid',
      PaymentStatus.disputed => 'Disputed',
      PaymentStatus.cancelled => 'Cancelled',
      PaymentStatus.unknown => 'Unknown',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currency.format(payment.amount), style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text('From: ${payment.debtorDisplayName}'),
            const SizedBox(height: 6),
            Text('To: ${payment.creditorDisplayName}'),
            const SizedBox(height: 6),
            Text('Reason: ${isForced ? 'Forced reassignment' : 'Bounty'}'),
            const SizedBox(height: 6),
            Text('Status: $status'),
            if (onSettle != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSettle,
                  child: const Text('MARK AS SETTLED'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}