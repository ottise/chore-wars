import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../home/presentation/providers/home_dashboard_provider.dart';
import '../providers/bounty_providers.dart';

class CreateBountyScreen extends ConsumerStatefulWidget {
  final String? houseId;
  final String? occurrenceId;
  final String? choreName;
  final String? deadline;

  const CreateBountyScreen({
    super.key,
    required this.houseId,
    required this.occurrenceId,
    required this.choreName,
    required this.deadline,
  });

  @override
  ConsumerState<CreateBountyScreen> createState() => _CreateBountyScreenState();
}

class _CreateBountyScreenState extends ConsumerState<CreateBountyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || widget.houseId == null || widget.occurrenceId == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final normalized = _amountController.text.trim().replaceAll('.', '').replaceAll(',', '.');
      await ref.read(bountyRepositoryProvider).createBounty(
            houseId: widget.houseId!,
            choreOccurrenceId: widget.occurrenceId!,
            amount: double.parse(normalized),
          );
      if (!mounted) return;
      ref.invalidate(bountyBoardProvider(widget.houseId!));
      ref.invalidate(homeDashboardProvider(widget.houseId!));
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = widget.houseId != null && widget.occurrenceId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Bounty')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Chore', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(widget.choreName ?? 'Chore details unavailable', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Text('Deadline', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(widget.deadline ?? 'Provided by the backend occurrence'),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Bounty amount',
                suffixText: 'đ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final normalized = value?.trim().replaceAll('.', '').replaceAll(',', '.');
                final amount = double.tryParse(normalized ?? '');
                if (amount == null || amount <= 0) return 'Enter a valid amount.';
                return null;
              },
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'POST BOUNTY',
              onPressed: canSubmit ? _submit : null,
              isLoading: _isSubmitting,
            ),
            if (!canSubmit) ...[
              const SizedBox(height: 12),
              const Text('A chore occurrence and house are required to post a bounty.'),
            ],
          ],
        ),
      ),
    );
  }
}