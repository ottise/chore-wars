import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import 'supplies_ui.dart';
import 'supply_fields_dialog.dart';

final supplyDisputesProvider = FutureProvider.autoDispose
    .family<List<SupplyData>, String>(
      (ref, id) => ref
          .watch(suppliesRepositoryProvider)
          .list('/supply-orders/$id/disputes'),
    );

class SupplyDisputesPanel extends ConsumerStatefulWidget {
  const SupplyDisputesPanel({
    required this.orderId,
    this.supplier = false,
    this.canReport = true,
    super.key,
  });
  final String orderId;
  final bool supplier;
  final bool canReport;
  @override
  ConsumerState<SupplyDisputesPanel> createState() =>
      _SupplyDisputesPanelState();
}

class _SupplyDisputesPanelState extends ConsumerState<SupplyDisputesPanel> {
  bool _busy = false;
  String? _error;
  String _requestId = const Uuid().v4();
  Future<void> _run(String path, SupplyData body) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(suppliesRepositoryProvider).mutate(path, body);
      if (mounted) {
        _requestId = const Uuid().v4();
        ref.invalidate(supplyDisputesProvider(widget.orderId));
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(userProfileProvider).asData?.value.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Purchase problems',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (!widget.supplier && widget.canReport)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final value = await showDialog<SupplyData>(
                      context: context,
                      builder: (_) => const SupplyFieldsDialog(
                        title: 'Report a purchase problem',
                        fields: {'reason': 'What is missing or damaged?'},
                      ),
                    );
                    if (value != null && mounted) {
                      await _run('/supply-orders/${widget.orderId}/disputes', {
                        'clientRequestId': _requestId,
                        ...value,
                      });
                    }
                  },
            child: const Text('Report missing or damaged goods'),
          ),
        ref
            .watch(supplyDisputesProvider(widget.orderId))
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => SupplyFailure(
                e,
                () => ref.invalidate(supplyDisputesProvider(widget.orderId)),
              ),
              data: (items) => Column(
                children: [
                  if (items.isEmpty) const Text('No problems reported.'),
                  for (final d in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SupplySurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['reason'].toString()),
                            if (d['resolution'] != null)
                              Text('Supplier response: ${d['resolution']}'),
                            if (d['acceptedAt'] != null)
                              const Text('Resolution accepted')
                            else ...[
                              if (widget.supplier)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          final value =
                                              await showDialog<SupplyData>(
                                                context: context,
                                                builder: (_) =>
                                                    const SupplyFieldsDialog(
                                                      title: 'Propose a resolution',
                                                      fields: {
                                                        'resolution': 'Replacement, delivery or refund arrangement',
                                                      },
                                                    ),
                                              );
                                          if (value != null && mounted) {
                                            await _run(
                                              '/supplier/orders/${widget.orderId}/disputes/${d['id']}/propose',
                                              value,
                                            );
                                          }
                                        },
                                  child: const Text('Respond to problem'),
                                ),
                              if (d['creatorUserId'] == me &&
                                  d['proposedAt'] != null)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          '/supply-orders/${widget.orderId}/disputes/${d['id']}/accept',
                                          {},
                                        ),
                                  child: const Text('Accept resolution'),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }
}
