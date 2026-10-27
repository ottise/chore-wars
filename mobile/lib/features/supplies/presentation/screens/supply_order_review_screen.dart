import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../house/presentation/providers/house_providers.dart';
import '../../domain/repositories/supplies_repository.dart';
import '../providers/supplies_providers.dart';
import '../widgets/supplies_ui.dart';

class SupplyOrderReviewScreen extends ConsumerStatefulWidget {
  const SupplyOrderReviewScreen({
    required this.houseId,
    this.selection,
    super.key,
  });
  final String houseId;
  final SupplyData? selection;
  @override
  ConsumerState<SupplyOrderReviewScreen> createState() =>
      _SupplyOrderReviewScreenState();
}

class _SupplyOrderReviewScreenState
    extends ConsumerState<SupplyOrderReviewScreen> {
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _requestId = const Uuid().v4();
  final _participants = <String>{};
  final _amounts = <String, TextEditingController>{};
  String? _payer;
  bool _custom = false;
  bool _initialized = false;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final meta = widget.selection?['aiDraft'] as Map?;
    _address.text = meta?['delivery_address']?.toString() ?? '';
    _phone.text = meta?['contact_phone']?.toString() ?? '';
    if (meta?['share_amounts'] is Map) {
      _custom = true;
      for (final e in (meta!['share_amounts'] as Map).entries) {
        _amounts[e.key.toString()] = TextEditingController(
          text: e.value.toString(),
        );
      }
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_participants.isEmpty || !_participants.contains(_payer)) {
      setState(() => _error = 'Choose participants including the payer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = widget.selection!;
      final products = s['products'] as List;
      final quantities = s['quantities'] as Map;
      final body = {
        'clientRequestId': _requestId,
        'supplierId': (s['supplier'] as Map)['id'],
        'payerUserId': _payer,
        'deliveryAddress': _address.text.trim(),
        'contactPhone': _phone.text.trim(),
        'viaAI':
            s['aiDraft'] != null && (s['aiDraft'] as Map)['via_ai'] != false,
        'lines': products
            .map((p) => {'productId': p['id'], 'quantity': quantities[p['id']]})
            .toList(),
        'shares': _participants
            .map(
              (id) => {
                'userId': id,
                if (_custom) 'amount': num.tryParse(_amounts[id]?.text ?? ''),
              },
            )
            .toList(),
      };
      final meta = s['aiDraft'] as Map?;
      final repository = ref.read(suppliesRepositoryProvider);
      final order = meta?['revise_order_id'] != null
          ? await repository.mutate(
              '/houses/${widget.houseId}/supply-orders/${meta!['revise_order_id']}',
              {'expectedVersion': meta['expected_version'], 'draft': body},
              method: 'PUT',
            )
          : await repository.create(widget.houseId, body);
      if (!mounted) return;
      ref.invalidate(supplyOrdersProvider(widget.houseId));
      context.go('/houses/${widget.houseId}/supplies/orders/${order['id']}');
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selection == null) {
      return SuppliesPage(
        title: 'Review purchase',
        child: Center(
          child: TextButton(
            onPressed: () => context.go('/houses/${widget.houseId}/supplies'),
            child: const Text('Choose products first'),
          ),
        ),
      );
    }
    final me = ref.watch(userProfileProvider).asData?.value.id;
    final s = widget.selection!;
    final supplier = s['supplier'] as Map;
    final products = s['products'] as List;
    final quantities = s['quantities'] as Map;
    final total =
        products.fold<num>(
          0,
          (sum, p) => sum + (p['price'] as num) * (quantities[p['id']] as num),
        ) +
        (supplier['deliveryFee'] as num? ?? 0);
    return SuppliesPage(
      title: 'Review purchase',
      child: ref
          .watch(houseMembersProvider(widget.houseId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SupplyFailure(
              e,
              () => ref.invalidate(houseMembersProvider(widget.houseId)),
            ),
            data: (members) {
              final active = members.where((m) => m.isActive).toList();
              if (!_initialized && me != null) {
                _initialized = true;
                _payer = me;
                final ai = s['aiDraft'] as Map?;
                final wanted = (ai?['participant_ids'] as List? ?? [me])
                    .map((x) => x.toString())
                    .toSet();
                _participants.addAll(
                  active
                      .where((m) => wanted.contains(m.userId))
                      .map((m) => m.userId),
                );
                if (ai?['payer_id'] != null &&
                    active.any((m) => m.userId == ai!['payer_id'])) {
                  _payer = ai!['payer_id'].toString();
                }
                _participants.add(_payer!);
              }
              return Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    SupplySurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final p in products)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${quantities[p['id']]} × ${p['name']} · ${supplyMoney(p['price'])} / ${p['unit']}',
                              ),
                            ),
                          Text(
                            'Delivery: ${supplyMoney(supplier['deliveryFee'])}',
                          ),
                          const Divider(),
                          Text(
                            'Total: ${supplyMoney(total)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _address,
                      decoration: const InputDecoration(
                        labelText: 'Delivery address',
                      ),
                      maxLength: 500,
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Enter a delivery address' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: 'Delivery phone',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 24,
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Enter a contact number' : null,
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: _payer,
                      decoration: const InputDecoration(
                        labelText: 'Who pays the supplier first?',
                      ),
                      items: active
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.userId,
                              child: Text(m.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                              _payer = v;
                              if (v != null) _participants.add(v);
                            }),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Each participant must approve their share before the payer can checkout. Others repay the payer directly.',
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enter individual shares'),
                      value: _custom,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _custom = v),
                    ),
                    for (final m in active)
                      Column(
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _participants.contains(m.userId),
                            title: Text(m.displayName),
                            subtitle: m.userId == _payer
                                ? const Text('Designated payer')
                                : null,
                            onChanged: _busy || m.userId == _payer
                                ? null
                                : (v) => setState(() {
                                    if (v == true) {
                                      _participants.add(m.userId);
                                    } else {
                                      _participants.remove(m.userId);
                                    }
                                  }),
                          ),
                          if (_custom && _participants.contains(m.userId))
                            TextFormField(
                              controller: _amounts.putIfAbsent(
                                m.userId,
                                TextEditingController.new,
                              ),
                              decoration: InputDecoration(
                                labelText: '${m.displayName} share (VND)',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => num.tryParse(v ?? '') == null
                                  ? 'Enter an amount in VND'
                                  : null,
                            ),
                        ],
                      ),
                    if (!_custom && _participants.isNotEmpty)
                      Text(
                        'About ${supplyMoney(total / _participants.length)} each. Exact rounding is shown in the saved quote.',
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _create,
                      child: Text(_busy ? 'Saving…' : 'Create draft'),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}
