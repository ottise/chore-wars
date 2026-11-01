import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import 'supplies_ui.dart';

class AiSupplyDraftCard extends ConsumerStatefulWidget {
  const AiSupplyDraftCard({
    required this.houseId,
    required this.candidate,
    super.key,
  });
  final String houseId;
  final SupplyData candidate;

  @override
  ConsumerState<AiSupplyDraftCard> createState() => _AiSupplyDraftCardState();
}

class _AiSupplyDraftCardState extends ConsumerState<AiSupplyDraftCard> {
  late final String _clientRequestId;
  SupplyData? _savedOrder;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clientRequestId =
        widget.candidate['client_request_id']?.toString() ?? const Uuid().v4();
    if ((widget.candidate['lines'] as List? ?? []).isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveOrder());
    }
  }

  Future<void> _saveOrder() async {
    if (_saving || _savedOrder != null || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final lines = (widget.candidate['lines'] as List? ?? [])
          .whereType<Map>()
          .map(
            (line) => {
              'productId': line['product_id'],
              'quantity': line['quantity'],
            },
          )
          .toList();
      if (lines.isEmpty || widget.candidate['supplier_id'] == null) {
        throw const FormatException(
          'The AI order is missing its supplier or items.',
        );
      }
      final order = await ref.read(suppliesRepositoryProvider).mutate(
        '/houses/${widget.houseId}/orders/send',
        {
          'clientRequestId': _clientRequestId,
          'supplierId': widget.candidate['supplier_id'],
          'lines': lines,
          'deliveryAddress': '',
          'contactPhone': '',
          'note': '',
          'viaAI': true,
        },
      );
      if (!mounted) return;
      setState(() => _savedOrder = order);
      ref.invalidate(supplyOrdersProvider(widget.houseId));
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.candidate['lines'] as List? ?? [];
    final displayLines = _savedOrder?['lines'] as List? ?? lines;
    final reminder = widget.candidate['reminder'];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SupplySurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lines.isEmpty
                  ? 'Group reminder'
                  : _savedOrder != null
                  ? 'Order saved as unpaid'
                  : _error != null
                  ? 'Could not save AI order'
                  : 'Saving AI order',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (lines.isNotEmpty) ...[
              for (final line in displayLines.whereType<Map>())
                Text(
                  '${line['quantity']} × ${line['name'] ?? line['product_id']}${line['unit'] == null ? '' : ' (${line['unit']})'}',
                ),
              const SizedBox(height: 6),
              if (_saving)
                const LinearProgressIndicator()
              else if (_savedOrder != null) ...[
                const Text(
                  'The order is in Orders → Unpaid. No payment has been made.',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => supplyOpenOrderSms(context, _savedOrder!),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Open SMS to supplier'),
                ),
              ] else if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton.icon(
                  onPressed: _saveOrder,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry saving order'),
                ),
              ],
            ],
            if (reminder is Map)
              TextButton(
                onPressed: () => context.push(
                  '/houses/${widget.houseId}/supplies/schedules',
                  extra: Map<String, dynamic>.from(reminder),
                ),
                child: const Text('Review group reminder'),
              ),
          ],
        ),
      ),
    );
  }
}
