import 'package:flutter/material.dart';

import '../../domain/repositories/supplies_repository.dart';

class SupplyFieldsDialog extends StatefulWidget {
  const SupplyFieldsDialog({
    required this.title,
    required this.fields,
    this.initial = const {},
    super.key,
  });
  final String title;
  final Map<String, String> fields;
  final Map<String, String> initial;
  @override
  State<SupplyFieldsDialog> createState() => _SupplyFieldsDialogState();
}

class _SupplyFieldsDialogState extends State<SupplyFieldsDialog> {
  late final _controllers = {
    for (final k in widget.fields.keys)
      k: TextEditingController(text: widget.initial[k] ?? ''),
  };
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in widget.fields.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextField(
                  controller: _controllers[e.key],
                  keyboardType: e.key == 'email'
                      ? TextInputType.emailAddress
                      : e.key == 'phone'
                      ? TextInputType.phone
                      : [
                          'price',
                          'amount',
                          'deliveryFee',
                          'availableQuantity',
                        ].contains(e.key)
                      ? TextInputType.number
                      : TextInputType.text,
                  autocorrect: !['email', 'reference', 'sku'].contains(e.key),
                  decoration: InputDecoration(labelText: e.value),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop<SupplyData>(context, {
          for (final e in _controllers.entries) e.key: e.value.text.trim(),
        }),
        child: const Text('Save'),
      ),
    ],
  );
}
