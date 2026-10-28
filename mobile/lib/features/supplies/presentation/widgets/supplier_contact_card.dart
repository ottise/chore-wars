import 'package:flutter/material.dart';

import '../../domain/repositories/supplies_repository.dart';
import 'supplies_ui.dart';

class SupplierContactCard extends StatelessWidget {
  const SupplierContactCard({required this.supplier, super.key});
  final SupplyData supplier;
  @override
  Widget build(BuildContext context) {
    final phone = supplier['phone']?.toString().trim() ?? '';
    final email = supplier['email']?.toString().trim() ?? '';
    return SupplySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supplier['name']?.toString() ?? 'Supplier',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (supplier['deliveryArea'] != null)
            Text(supplier['deliveryArea'].toString()),
          const SizedBox(height: 8),
          Text(phone.isEmpty ? 'Contact number not available' : phone),
          if (phone.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      supplyLaunch(context, Uri(scheme: 'tel', path: phone)),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
                TextButton(
                  onPressed: () => supplyCopy(context, 'Phone', phone),
                  child: const Text('Copy number'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      supplyLaunch(context, Uri(scheme: 'sms', path: phone)),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Message'),
                ),
              ],
            ),
          if (email.isNotEmpty)
            TextButton.icon(
              onPressed: () =>
                  supplyLaunch(context, Uri(scheme: 'mailto', path: email)),
              icon: const Icon(Icons.mail_outline),
              label: Text(email),
            ),
        ],
      ),
    );
  }
}
