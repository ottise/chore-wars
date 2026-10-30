import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/api_error_message.dart';
import '../providers/supplies_providers.dart';
import 'shop_presets.dart';

class ShopItemDialog extends ConsumerStatefulWidget {
  const ShopItemDialog({required this.houseId, this.preset, super.key});
  final String houseId;
  final ShopPreset? preset;

  @override
  ConsumerState<ShopItemDialog> createState() => _ShopItemDialogState();
}

class _ShopItemDialogState extends ConsumerState<ShopItemDialog> {
  final _form = GlobalKey<FormState>();
  final _fields = List.generate(6, (_) => TextEditingController());
  String _requestId = const Uuid().v4();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    if (preset != null) {
      _fields[0].text = preset.name;
      _fields[1].text = preset.unit;
      _fields[2].text = '${preset.price}';
      _fields[3].text = '${preset.name} supplier';
    }
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref.read(suppliesRepositoryProvider).mutate(
        '/houses/${widget.houseId}/shop/items',
        {
          'clientRequestId': _requestId,
          'name': _fields[0].text.trim(),
          'unit': _fields[1].text.trim(),
          'price': int.parse(_fields[2].text.trim()),
          'contactName': _fields[3].text.trim(),
          'phone': _fields[4].text.trim(),
          'email': _fields[5].text.trim(),
        },
      );
      ref.invalidate(houseShopSuppliersProvider(widget.houseId));
      if (mounted) {
        Navigator.of(context).pop(result['supplier']?['id']?.toString());
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Add shop item'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            onChanged: () => _requestId = const Uuid().v4(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.preset != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'This is an editable suggestion. Confirm the price with your supplier.',
                    ),
                  ),
                for (var index = 0; index < _fields.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _fields[index],
                      enabled: !_saving,
                      maxLength: [150, 40, 12, 120, 24, 254][index],
                      keyboardType: switch (index) {
                        2 => TextInputType.number,
                        4 => TextInputType.phone,
                        5 => TextInputType.emailAddress,
                        _ => TextInputType.text,
                      },
                      decoration: InputDecoration(
                        labelText: [
                          'Item name',
                          'Unit (e.g. 5 kg bag)',
                          'Price (VND)',
                          'Contact name',
                          'Phone number',
                          'Email',
                        ][index],
                      ),
                      validator: (raw) {
                        final value = raw?.trim() ?? '';
                        if (index < 5 && value.isEmpty) {
                          return 'This field is required.';
                        }
                        if (index == 2) {
                          final price = int.tryParse(value);
                          if (price == null ||
                              price <= 0 ||
                              price > 1000000000) {
                            return 'Enter a whole VND amount from 1 to 1,000,000,000.';
                          }
                        }
                        if (index == 4 &&
                            value.isNotEmpty &&
                            !RegExp(r'^\+?[0-9 ()\-]{6,24}$').hasMatch(value)) {
                          return 'Enter a valid phone number.';
                        }
                        if (index == 5 &&
                            value.isNotEmpty &&
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(value)) {
                          return 'Enter a valid email address.';
                        }
                        if (index >= 4 &&
                            _fields[4].text.trim().isEmpty &&
                            _fields[5].text.trim().isEmpty) {
                          return 'Enter a phone number or email.';
                        }
                        return null;
                      },
                    ),
                  ),
                const Text(
                  'Saved for this household. A phone number is required to prepare an SMS order. Email is optional contact information.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save item'),
        ),
      ],
    ),
  );
}
